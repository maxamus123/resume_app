require 'securerandom'

class AssistantService
  BASE_URL = "https://api.openai.com/v1".freeze

  def initialize
    @api_key = ENV.fetch('OPENAI_ACCESS_TOKEN')
  end

  def analyze_job_description(job_description)
    temp_file = Tempfile.new(['job_description', '.pdf'])
    temp_file.binmode
    temp_file.write(job_description.document.download)
    temp_file.rewind

    log_info("Uploading file")
    file_response = upload_file(temp_file.path)
    return error_response("Error uploading file") unless file_response["id"]

    file_id = file_response["id"]
    log_info("File uploaded with ID: #{file_id}")

    assistant_response = create_assistant(file_id)
    return error_response("Error creating assistant") unless assistant_response["id"]

    assistant_id = assistant_response["id"]
    vector_store_id = assistant_response.dig("tool_resources", "file_search", "vector_store_ids")&.first
    log_info("Assistant created with ID: #{assistant_id} and vector store ID: #{vector_store_id}")

    thread_response = create_thread
    return error_response("Error creating thread") unless thread_response["id"]

    thread_id = thread_response["id"]
    log_info("Thread created with ID: #{thread_id}")

    user_prompt = create_user_prompt(job_description)
    message_response = add_message_to_thread(thread_id, user_prompt)
    return error_response("Error adding message to thread") if message_response["error"]

    run_response = run_assistant(thread_id, assistant_id)
    return error_response("Error running assistant") if run_response["error"] || run_response["status"] == "failed"

    run_id = run_response["id"]
    unless wait_for_run_completion(thread_id, run_id)
      log_error("Assistant run timed out")
      cleanup_resources(file_id, assistant_id, thread_id, vector_store_id)
      return error_response("The analysis is taking too long. Please try again later.")
    end

    messages_response = get_thread_messages(thread_id)
    if messages_response["error"]
      log_error("Getting messages failed: #{messages_response['error']}")
      cleanup_resources(file_id, assistant_id, thread_id, vector_store_id)
      return error_response("Error retrieving the analysis results")
    end

    analysis_text = messages_response["data"].find { |msg| msg["role"] == "assistant" }
    result = analysis_text ? analysis_text["content"][0]["text"]["value"] : "No analysis was generated."
    cleanup_resources(file_id, assistant_id, thread_id, vector_store_id)
    result
  rescue StandardError => e
    log_error("Error in analyze_job_description: #{e.message}")
    "Sorry, an error occurred: #{e.message}"
  ensure
    temp_file.close
    temp_file.unlink if temp_file
  end

  def upload_file(file_path)
    url = "#{BASE_URL}/files"
    file_content = File.binread(file_path)
    boundary = "----RubyFormBoundary#{SecureRandom.hex(15)}"
    body = [
      "--#{boundary}\r\n",
      "Content-Disposition: form-data; name=\"purpose\"\r\n\r\n",
      "assistants\r\n",
      "--#{boundary}\r\n",
      "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(file_path)}\"\r\n",
      "Content-Type: application/pdf\r\n\r\n",
      file_content,
      "\r\n--#{boundary}--\r\n"
    ].join

    headers = api_headers.merge({
                                  "Content-Type" => "multipart/form-data; boundary=#{boundary}",
                                  "Content-Length" => body.bytesize.to_s,
                                  "OpenAI-Beta" => "assistants=v2"
                                })

    response = Faraday.post(url) do |req|
      req.headers = headers
      req.body = body
    end
    response.status == 200 ? JSON.parse(response.body) : { "error" => "File upload failed with status #{response.status}" }
  end

  def create_vector_store(file_id)
    url = "#{BASE_URL}/vector_stores"
    payload = { name: "Job Description Vector Store", file_ids: [file_id] }
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
      req.body = payload.to_json
    end
    response.status == 200 ? JSON.parse(response.body) : { "error" => "Vector store creation failed with status #{response.status}" }
  end

  def create_assistant(file_id)
    vector_store_response = create_vector_store(file_id)
    return { "error" => "Vector store creation failed" } if vector_store_response["error"]
    vector_store_id = vector_store_response["id"]
    log_info("Vector store created with ID: #{vector_store_id}")

    url = "#{BASE_URL}/assistants"
    payload = {
      name: "Job Description Analyzer",
      description: "Analyzes job descriptions for Maxwell Creamer",
      model: "gpt-4o",
      instructions: create_assistant_instructions,
      tools: [{ type: "file_search" }],
      tool_resources: { file_search: { vector_store_ids: [vector_store_id] } }
    }
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
      req.body = payload.to_json
    end
    response.status == 200 ? JSON.parse(response.body) : { "error" => "Assistant creation failed with status #{response.status}" }
  end

  def create_thread
    url = "#{BASE_URL}/threads"
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
      req.body = {}.to_json
    end
    response.status == 200 ? JSON.parse(response.body) : { "error" => "Thread creation failed with status #{response.status}" }
  end

  def add_message_to_thread(thread_id, content)
    url = "#{BASE_URL}/threads/#{thread_id}/messages"
    payload = { role: "user", content: content }
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
      req.body = payload.to_json
    end
    response.status == 200 ? JSON.parse(response.body) : { "error" => "Adding message failed with status #{response.status}" }
  end

  def run_assistant(thread_id, assistant_id)
    url = "#{BASE_URL}/threads/#{thread_id}/runs"
    payload = { assistant_id: assistant_id }
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
      req.body = payload.to_json
    end
    response.status == 200 ? JSON.parse(response.body) : { "error" => "Running assistant failed with status #{response.status}" }
  end

  def get_run_status(thread_id, run_id)
    url = "#{BASE_URL}/threads/#{thread_id}/runs/#{run_id}"
    response = Faraday.get(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
    end
    response.status == 200 ? JSON.parse(response.body) : { "error" => "Getting run status failed with status #{response.status}" }
  end

  def wait_for_run_completion(thread_id, run_id, timeout = 60, sleep_interval = 1)
    start_time = Time.now
    loop do
      return false if Time.now - start_time > timeout
      status = get_run_status(thread_id, run_id)["status"]
      return true if status == "completed"
      return false if %w[failed cancelled expired].include?(status)
      sleep(sleep_interval)
    end
  end

  def get_thread_messages(thread_id)
    url = "#{BASE_URL}/threads/#{thread_id}/messages"
    response = Faraday.get(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
    end
    response.status == 200 ? JSON.parse(response.body) : { "error" => "Getting messages failed with status #{response.status}" }
  end

  def cleanup_resources(file_id, assistant_id, thread_id, vector_store_id = nil)
    cleanup_resource("files", file_id, "File")
    cleanup_resource("assistants", assistant_id, "Assistant")
    cleanup_resource("threads", thread_id, "Thread")
    cleanup_resource("vector_stores", vector_store_id, "Vector store") if vector_store_id
  end

  def cleanup_resource(endpoint, id, name)
    url = "#{BASE_URL}/#{endpoint}/#{id}"
    response = Faraday.delete(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
    end
    log_warn("#{name} cleanup failed with status #{response.status}: #{response.body}") unless response.status == 200
  end

  def create_assistant_instructions
    <<~INSTRUCTIONS
      You are a professional AI assistant evaluating Maxwell Creamer's fit for a specific job role.
      Your task is to analyze the uploaded job description document and assess how well Maxwell's background, skills, and experience align with the job requirements.
      MAXWELL'S PROFILE:
      - Senior Software Engineer with Ruby on Rails expertise
      - Proven leadership and innovation in AI integration
      - Experience with asynchronous job processing (e.g., Sidekiq)
      Technical skills:
      - Expert in Ruby on Rails and database optimization
      - Familiarity with large-scale item batch processing
      Achievements:
      - Led development of AI-powered solutions
      - Streamlined curriculum creation processes
      Format your response as:
      1. OVERVIEW
      2. KEY QUALIFICATIONS MATCH
      3. UNIQUE VALUE PROPOSITION
      4. POTENTIAL CHALLENGES AND SOLUTIONS
      5. CONCLUSION
    INSTRUCTIONS
  end

  def create_user_prompt(job_description)
    job_info = "Job Title: #{job_description.title}\n"
    job_info += "Company: #{job_description.company}\n" if job_description.company.present?
    <<~PROMPT
      Please analyze the attached job description document for the following position:
      #{job_info}
      Explain why I (Maxwell Creamer) would be a good fit for this position based on my profile.
    PROMPT
  end

  def api_headers
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{@api_key}" }
  end

  def error_response(message)
    "Sorry, #{message}."
  end

  private

  def log_info(message)
    Rails.logger.info(message)
  end

  def log_error(message)
    Rails.logger.error(message)
  end

  def log_warn(message)
    Rails.logger.warn(message)
  end
end
