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

    # Track created resources for cleanup
    resources = {}

    begin
      log_info("Uploading file")
      file_response = upload_file(temp_file.path)
      if file_response["error"]
        log_error("File upload failed: #{file_response['error']}")
        return error_response("Error uploading file")
      end

      resources[:file_id] = file_response["id"]
      log_info("File uploaded with ID: #{resources[:file_id]}")

      assistant_response = create_assistant(resources[:file_id])
      if assistant_response["error"]
        cleanup_resources({ file_id: resources[:file_id] })
        return error_response("Error creating assistant")
      end

      resources[:assistant_id] = assistant_response["id"]
      resources[:vector_store_id] = assistant_response.dig("tool_resources", "file_search", "vector_store_ids")&.first
      log_info("Assistant created with ID: #{resources[:assistant_id]} and vector store ID: #{resources[:vector_store_id]}")

      thread_response = create_thread
      if thread_response["error"]
        cleanup_resources(resources)
        return error_response("Error creating thread")
      end

      resources[:thread_id] = thread_response["id"]
      log_info("Thread created with ID: #{resources[:thread_id]}")

      user_prompt = create_user_prompt(job_description)
      message_response = add_message_to_thread(resources[:thread_id], user_prompt)
      if message_response["error"]
        cleanup_resources(resources)
        return error_response("Error adding message to thread")
      end

      run_response = run_assistant(resources[:thread_id], resources[:assistant_id])
      if run_response["error"] || run_response["status"] == "failed"
        cleanup_resources(resources)
        return error_response("Error running assistant")
      end

      run_id = run_response["id"]
      unless wait_for_run_completion(resources[:thread_id], run_id)
        cleanup_resources(resources)
        log_error("Assistant run timed out")
        return error_response("The analysis is taking too long. Please try again later.")
      end

      messages_response = get_thread_messages(resources[:thread_id])
      if messages_response["error"]
        cleanup_resources(resources)
        log_error("Getting messages failed: #{messages_response['error']}")
        return error_response("Error retrieving the analysis results")
      end

      analysis_text = messages_response["data"].find { |msg| msg["role"] == "assistant" }
      result = analysis_text ? analysis_text["content"][0]["text"]["value"] : "No analysis was generated."
      
      # Only clean up after successful analysis
      cleanup_resources(resources)
      return result
    rescue StandardError => e
      log_error("Error in analyze_job_description: #{e.message}")
      log_error(e.backtrace.join("\n")) if e.backtrace
      # Clean up resources if we have any
      cleanup_resources(resources) unless resources.empty?
      return "Sorry, an error occurred: #{e.message}"
    ensure
      # Only clean up the temporary file
      begin
        temp_file.close
        temp_file.unlink if temp_file
      rescue => file_error
        log_error("Error cleaning up temporary file: #{file_error.message}")
      end
    end
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

  def cleanup_resources(resources)
    successful_cleanups = []
    failed_cleanups = []

    # Clean up the thread
    if resources[:thread_id]
      result = cleanup_resource("threads", resources[:thread_id], "Thread")
      result ? successful_cleanups << "Thread" : failed_cleanups << "Thread"
    end

    # Clean up the assistant
    if resources[:assistant_id]
      result = cleanup_resource("assistants", resources[:assistant_id], "Assistant")
      result ? successful_cleanups << "Assistant" : failed_cleanups << "Assistant"
    end

    # Clean up the vector store
    if resources[:vector_store_id]
      result = cleanup_resource("vector_stores", resources[:vector_store_id], "Vector store")
      result ? successful_cleanups << "Vector store" : failed_cleanups << "Vector store"
    end

    # Clean up the file
    if resources[:file_id]
      result = cleanup_resource("files", resources[:file_id], "File")
      result ? successful_cleanups << "File" : failed_cleanups << "File"
    end

    # Log summary of cleanup operation
    if failed_cleanups.empty?
      log_info("Successfully cleaned up all resources: #{successful_cleanups.join(', ')}")
    else
      log_warn("Some resources failed to clean up: #{failed_cleanups.join(', ')}")
      log_info("Successfully cleaned up: #{successful_cleanups.join(', ')}") unless successful_cleanups.empty?
    end
  end

  def cleanup_resource(endpoint, id, name)
    url = "#{BASE_URL}/#{endpoint}/#{id}"
    response = Faraday.delete(url) do |req|
      req.headers = api_headers.merge({ "OpenAI-Beta" => "assistants=v2" })
    end
    
    if response.status == 200
      log_info("#{name} deleted successfully: #{id}")
      return true
    else
      log_warn("#{name} cleanup failed with status #{response.status}: #{response.body}")
      return false
    end
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

      Format your response using proper Markdown syntax for enhanced readability.
      DO NOT include any citation markers or references to the source document in the output.

      # Analysis Results

      ## OVERVIEW
      Write a concise overview of the role and its key requirements. Use **bold** for emphasis on critical points.

      ## KEY QUALIFICATIONS MATCH

      ### Leadership and Team Management
      Describe leadership match...

      ### Technical Expertise
      Describe technical match...

      ### Process Optimization
      Describe process optimization match...

      ### Communication Skills
      Describe communication skills match...

      ## UNIQUE VALUE PROPOSITION
      List unique strengths as bullet points:
      - Each point should be concise and specific
      - Focus on differentiating factors
      
      ## POTENTIAL CHALLENGES AND SOLUTIONS

      ### Challenge 1: [Name]
      **Challenge:**  
      Description of the challenge...

      **Solution:**  
      Proposed solution...

      ### Challenge 2: [Name]
      **Challenge:**  
      Description of the challenge...

      **Solution:**  
      Proposed solution...

      ## CONCLUSION
      Write a strong conclusion that:
      - Uses *italics* for key takeaways
      - Uses **bold** for final recommendation
      - Ends with a clear statement about fit for the role

      Formatting Guidelines:
      1. Use proper Markdown headers (# for main title, ## for sections, ### for subsections)
      2. Add blank lines between sections for better readability
      3. Use **bold** for emphasis on important points
      4. Use *italics* for subtle emphasis
      5. Use bullet points for lists
      6. Use > for important quotes or highlights
      7. Format challenges and solutions with clear headings and spacing
      8. DO NOT include any file references or citations in the text
      9. Keep paragraphs concise and well-spaced
      10. Use line breaks effectively for readability
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
