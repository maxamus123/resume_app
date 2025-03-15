require 'securerandom'

class OpenaiService
  def initialize
    @api_key = ENV['OPENAI_ACCESS_TOKEN']
  end

  def chat(messages, max_tokens: 4000)
    payload = {
      model: "gpt-4-turbo",
      messages: messages,
      max_tokens: max_tokens
    }

    Rails.logger.info("Making API request to OpenAI with payload: #{payload.to_json}")
    response = Faraday.post(api_url) do |req|
      req.headers = api_headers
      req.body = payload.to_json
    end

    Rails.logger.info("Response status: #{response.status}")
    Rails.logger.info("Response body: #{response.body}")

    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("API request failed with status #{response.status}: #{response.body}")
      { "error" => "API request failed with status #{response.status}: #{response.body}" }
    end
  end

  def stream_chat(messages, max_tokens: 4000)
    payload = {
      model: "gpt-4-turbo",
      messages: messages,
      max_tokens: max_tokens,
      stream: true
    }

    Rails.logger.info("Making streaming API request to OpenAI")
    accumulated_text = ""

    begin
      conn = Faraday.new { |f| f.response :raise_error }
      conn.post(api_url) do |req|
        req.headers = api_headers
        req.body = payload.to_json
        req.options.on_data = Proc.new do |chunk, _|
          chunk.split("\n").each do |line|
            if line.start_with?('data: ') && !line.include?('data: [DONE]')
              data = line.sub('data: ', '')
              begin
                parsed = JSON.parse(data)
                if (delta = parsed.dig('choices', 0, 'delta', 'content'))
                  accumulated_text << delta
                  yield delta if block_given?
                end
              rescue JSON::ParserError => e
                Rails.logger.error("Error parsing JSON from stream: #{e.message}")
              end
            end
          end
        end
      end
      accumulated_text
    rescue Faraday::Error => e
      Rails.logger.error("Streaming API request failed: #{e.message}")
      error_message = "Error: #{e.message}"
      yield error_message if block_given?
      error_message
    end
  end

  def resume_chat(query, conversation = nil)
    messages = build_messages(query, conversation)
    response = chat(messages)
    if response["choices"]&.first&.dig("message", "content")
      response["choices"].first["message"]["content"]
    elsif response["error"]
      "Error: #{response['error']}"
    else
      "I'm sorry, I encountered an error processing your request."
    end
  end

  def stream_resume_chat(query, conversation = nil, &block)
    messages = build_messages(query, conversation)
    stream_chat(messages, &block)
  end

  def analyze_job_fit(job_description)
    # Build a special prompt for job description analysis
    if job_description.document.attached?
      # Use the Assistants API for PDF processing
      Rails.logger.info("Using Assistants API for document analysis")
      assistant_analysis(job_description)
    else
      # Use the regular model if no document
      Rails.logger.info("Using regular chat for job title analysis")
      prompt = job_description_analysis_prompt(job_description)
      messages = [
        { role: "system", content: prompt },
        { role: "user", content: "Please analyze this job description and tell me why I would be a good fit based on my profile." }
      ]
      response = chat(messages, max_tokens: 4000)
      
      # Return the analysis text
      if response["choices"] && response["choices"].first
        response["choices"].first["message"]["content"]
      else
        "Sorry, I couldn't analyze this job description. Please try again."
      end
    end
  end

  def job_description_analysis_prompt(job_description)
    # This is used only when there's no document attached
    
    # Combine all available job information
    job_info = "Job Title: #{job_description.title}\n"
    job_info += "Company: #{job_description.company}\n" if job_description.company.present?
    
    <<~PROMPT
      You are a professional AI assistant evaluating Maxwell Creamer's fit for a specific job role.
      
      YOUR TASK:
      Analyze the following job description and explain in detail why Maxwell would be an excellent fit for this position.
      
      JOB DETAILS:
      #{job_info}
      
      MAXWELL'S PROFILE:
      - Senior Software Engineer with three years of full-stack Ruby on Rails experience
      - Senior Engineer & Founding Member of StrongMind's skunkworks team, pioneering AI integration into educational products
      - Global Tech Liaison facilitating international team collaboration, especially with engineers from the Philippines
      - Product Manager recognized for developing scalable, pedagogically sound AI-driven products
      
      TECHNICAL SKILLS:
      - Expert in Ruby on Rails with a preference for clear, efficient, well-structured code
      - Experience with Sidekiq for asynchronous job processing in educational content management
      - Database optimization expertise
      - Experience with Learnosity for large-scale item batch processing
      - Implementation of advanced AI techniques: chain-of-thought and tree-of-thought methodologies
      
      ACHIEVEMENTS:
      - Led development of an AI-powered educational content generator using chain-of-thought and tree-of-thought methodologies
      - Expert in integrating large language models (LLMs) into web applications
      - Significantly reduced manual curriculum creation time, improving workflow efficiency
      - Developed algorithms for grouping elements into chronological units with flexible bucket sizes
      - Core team member for CourseBuilder v2, adding functionality for generating course content outlines
      - Spearheaded international expansion, organizing satellite offices in Rexburg, Idaho and Manila, Philippines
      - Facilitated intercultural team-building, hosting Filipino engineers at U.S. headquarters
      
      FORMAT YOUR RESPONSE AS FOLLOWS:
      
      1. OVERVIEW: A summary of the job and how Maxwell's background aligns with it (2-3 sentences)
      
      2. KEY QUALIFICATIONS MATCH:
         - List 3-5 specific qualifications from the job description and directly match them to Maxwell's experience
         - Format as "Job Requirement: [requirement] → Maxwell's Experience: [relevant experience]"
      
      3. UNIQUE VALUE PROPOSITION:
         - Explain 2-3 ways Maxwell brings exceptional or unique value to this role beyond the basic requirements
      
      4. POTENTIAL CHALLENGES AND SOLUTIONS:
         - Identify 1-2 potential areas where Maxwell might need to grow or adapt
         - Suggest how Maxwell could address these challenges
      
      5. CONCLUSION: Final recommendation on fit (1-2 sentences)
    PROMPT
  end

  private

  def api_url
    "https://api.openai.com/v1/chat/completions"
  end

  def api_headers
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@api_key}"
    }
  end
  
  def assistant_analysis(job_description)
    begin
      # 1. Create a temporary file from the ActiveStorage attachment
      temp_file = Tempfile.new(['job_description', '.pdf'])
      temp_file.binmode
      temp_file.write(job_description.document.download)
      temp_file.rewind
      
      # 2. Upload the file to OpenAI
      Rails.logger.info("Uploading file to OpenAI")
      file_response = upload_file(temp_file.path)
      
      if file_response["error"]
        Rails.logger.error("File upload failed: #{file_response['error']}")
        return "Sorry, I couldn't analyze this document. Error uploading file."
      end
      
      file_id = file_response["id"]
      Rails.logger.info("File uploaded with ID: #{file_id}")
      
      # 3. Create an assistant with file search capability
      assistant_response = create_assistant(file_id)
      
      if assistant_response["error"]
        Rails.logger.error("Assistant creation failed: #{assistant_response['error']}")
        cleanup_file(file_id)
        return "Sorry, I couldn't analyze this document. Error creating assistant."
      end
      
      assistant_id = assistant_response["id"]
      vector_store_id = nil
      
      # Extract the vector store ID if present
      if assistant_response["tool_resources"] && assistant_response["tool_resources"]["file_search"] && assistant_response["tool_resources"]["file_search"]["vector_store_ids"]
        vector_store_id = assistant_response["tool_resources"]["file_search"]["vector_store_ids"].first
        Rails.logger.info("Using vector store with ID: #{vector_store_id}")
      end
      
      Rails.logger.info("Assistant created with ID: #{assistant_id}")
      
      # 4. Create a thread
      thread_response = create_thread
      
      if thread_response["error"]
        Rails.logger.error("Thread creation failed: #{thread_response['error']}")
        cleanup_file(file_id)
        cleanup_assistant(assistant_id)
        cleanup_vector_store(vector_store_id) if vector_store_id
        return "Sorry, I couldn't analyze this document. Error creating thread."
      end
      
      thread_id = thread_response["id"]
      Rails.logger.info("Thread created with ID: #{thread_id}")
      
      # 5. Add a message to the thread
      user_prompt = create_user_prompt(job_description)
      message_response = add_message_to_thread(thread_id, user_prompt)
      
      if message_response["error"]
        Rails.logger.error("Adding message failed: #{message_response['error']}")
        cleanup_file(file_id)
        cleanup_assistant(assistant_id)
        cleanup_vector_store(vector_store_id) if vector_store_id
        cleanup_thread(thread_id)
        return "Sorry, I couldn't analyze this document. Error adding message to thread."
      end
      
      # 6. Run the assistant on the thread
      run_response = run_assistant(thread_id, assistant_id)
      
      if run_response["error"] || run_response["status"] == "failed"
        Rails.logger.error("Assistant run failed: #{run_response['error'] || run_response['status']}")
        cleanup_resources(file_id, assistant_id, thread_id, vector_store_id)
        return "Sorry, I couldn't analyze this document. The analysis process failed."
      end
      
      # 7. Wait for completion (with timeout)
      run_id = run_response["id"]
      completed = wait_for_run_completion(thread_id, run_id)
      
      if !completed
        Rails.logger.error("Assistant run timed out")
        cleanup_resources(file_id, assistant_id, thread_id, vector_store_id)
        return "Sorry, the analysis is taking too long. Please try again later."
      end
      
      # 8. Get the assistant's response
      messages_response = get_thread_messages(thread_id)
      
      if messages_response["error"]
        Rails.logger.error("Getting messages failed: #{messages_response['error']}")
        cleanup_resources(file_id, assistant_id, thread_id, vector_store_id)
        return "Sorry, I couldn't retrieve the analysis results."
      end
      
      # 9. Extract the assistant's message content
      assistant_message = messages_response["data"].find { |msg| msg["role"] == "assistant" }
      analysis_text = assistant_message ? assistant_message["content"][0]["text"]["value"] : "No analysis was generated."
      
      # 10. Clean up resources
      cleanup_resources(file_id, assistant_id, thread_id, vector_store_id)
      
      # Return the analysis
      analysis_text
      
    rescue StandardError => e
      Rails.logger.error("Error in assistant_analysis: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      "Sorry, an error occurred while analyzing the document: #{e.message}"
    ensure
      # Clean up the temporary file
      temp_file.close
      temp_file.unlink if temp_file
    end
  end
  
  def upload_file(file_path)
    url = "https://api.openai.com/v1/files"
    
    # Read file content
    file_content = File.binread(file_path)
    
    # Generate a boundary for multipart form
    boundary = "----RubyFormBoundary#{SecureRandom.hex(15)}"
    
    # Create multipart form data manually
    post_body = []
    post_body << "--#{boundary}\r\n"
    post_body << "Content-Disposition: form-data; name=\"purpose\"\r\n\r\n"
    post_body << "assistants\r\n"
    post_body << "--#{boundary}\r\n"
    post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(file_path)}\"\r\n"
    post_body << "Content-Type: application/pdf\r\n\r\n"
    post_body << file_content
    post_body << "\r\n--#{boundary}--\r\n"
    
    # Join all parts into a single string
    body = post_body.join
    
    # Create headers with multipart content type
    headers = api_headers.merge({
      "Content-Type" => "multipart/form-data; boundary=#{boundary}",
      "Content-Length" => body.bytesize.to_s,
      "OpenAI-Beta" => "assistants=v2"
    })
    
    # Make the request
    conn = Faraday.new(url: url) do |faraday|
      faraday.adapter Faraday.default_adapter
    end
    
    response = conn.post do |req|
      req.headers = headers
      req.body = body
    end
    
    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("File upload failed with status #{response.status}: #{response.body}")
      { "error" => "File upload failed with status #{response.status}: #{response.body}" }
    end
  end
  
  def create_assistant(file_id)
    # First create a vector store with the file
    vector_store_response = create_vector_store(file_id)
    
    if vector_store_response["error"]
      Rails.logger.error("Vector store creation failed: #{vector_store_response['error']}")
      return { "error" => "Vector store creation failed: #{vector_store_response['error']}" }
    end
    
    vector_store_id = vector_store_response["id"]
    Rails.logger.info("Vector store created with ID: #{vector_store_id}")
    
    # Then create the assistant with the vector store
    url = "https://api.openai.com/v1/assistants"
    
    payload = {
      name: "Job Description Analyzer",
      description: "An assistant that analyzes job descriptions to determine fit for Maxwell Creamer",
      model: "gpt-4o",
      instructions: create_assistant_instructions,
      tools: [{ type: "file_search" }],
      tool_resources: {
        file_search: {
          vector_store_ids: [vector_store_id]
        }
      }
    }
    
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
      req.body = payload.to_json
    end
    
    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("Assistant creation failed with status #{response.status}: #{response.body}")
      { "error" => "Assistant creation failed with status #{response.status}: #{response.body}" }
    end
  end
  
  def create_vector_store(file_id)
    url = "https://api.openai.com/v1/vector_stores"
    
    payload = {
      name: "Job Description Vector Store",
      file_ids: [file_id]
    }
    
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
      req.body = payload.to_json
    end
    
    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("Vector store creation failed with status #{response.status}: #{response.body}")
      { "error" => "Vector store creation failed with status #{response.status}: #{response.body}" }
    end
  end
  
  def create_thread
    url = "https://api.openai.com/v1/threads"
    
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
      req.body = {}.to_json
    end
    
    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("Thread creation failed with status #{response.status}: #{response.body}")
      { "error" => "Thread creation failed with status #{response.status}: #{response.body}" }
    end
  end
  
  def add_message_to_thread(thread_id, content)
    url = "https://api.openai.com/v1/threads/#{thread_id}/messages"
    
    payload = {
      role: "user",
      content: content
    }
    
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
      req.body = payload.to_json
    end
    
    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("Adding message failed with status #{response.status}: #{response.body}")
      { "error" => "Adding message failed with status #{response.status}: #{response.body}" }
    end
  end
  
  def run_assistant(thread_id, assistant_id)
    url = "https://api.openai.com/v1/threads/#{thread_id}/runs"
    
    payload = {
      assistant_id: assistant_id
    }
    
    response = Faraday.post(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
      req.body = payload.to_json
    end
    
    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("Running assistant failed with status #{response.status}: #{response.body}")
      { "error" => "Running assistant failed with status #{response.status}: #{response.body}" }
    end
  end
  
  def get_run_status(thread_id, run_id)
    url = "https://api.openai.com/v1/threads/#{thread_id}/runs/#{run_id}"
    
    response = Faraday.get(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
    end
    
    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("Getting run status failed with status #{response.status}: #{response.body}")
      { "error" => "Getting run status failed with status #{response.status}: #{response.body}" }
    end
  end
  
  def wait_for_run_completion(thread_id, run_id, timeout = 60, sleep_interval = 1)
    start_time = Time.now
    
    loop do
      # Check if we've exceeded the timeout
      elapsed = Time.now - start_time
      return false if elapsed > timeout
      
      # Get the current status
      run_status = get_run_status(thread_id, run_id)
      status = run_status["status"]
      
      # Return true if the run completed successfully
      return true if status == "completed"
      
      # Return false if the run failed or was cancelled
      return false if ["failed", "cancelled", "expired"].include?(status)
      
      # Sleep before checking again
      sleep(sleep_interval)
    end
  end
  
  def get_thread_messages(thread_id)
    url = "https://api.openai.com/v1/threads/#{thread_id}/messages"
    
    response = Faraday.get(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
    end
    
    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("Getting messages failed with status #{response.status}: #{response.body}")
      { "error" => "Getting messages failed with status #{response.status}: #{response.body}" }
    end
  end
  
  def cleanup_resources(file_id, assistant_id, thread_id, vector_store_id = nil)
    cleanup_file(file_id)
    cleanup_assistant(assistant_id)
    cleanup_thread(thread_id)
    cleanup_vector_store(vector_store_id) if vector_store_id
  end
  
  def cleanup_file(file_id)
    url = "https://api.openai.com/v1/files/#{file_id}"
    
    response = Faraday.delete(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
    end
    
    unless response.status == 200
      Rails.logger.warn("File cleanup failed with status #{response.status}: #{response.body}")
    end
  end
  
  def cleanup_assistant(assistant_id)
    url = "https://api.openai.com/v1/assistants/#{assistant_id}"
    
    response = Faraday.delete(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
    end
    
    unless response.status == 200
      Rails.logger.warn("Assistant cleanup failed with status #{response.status}: #{response.body}")
    end
  end
  
  def cleanup_thread(thread_id)
    url = "https://api.openai.com/v1/threads/#{thread_id}"
    
    response = Faraday.delete(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
    end
    
    unless response.status == 200
      Rails.logger.warn("Thread cleanup failed with status #{response.status}: #{response.body}")
    end
  end
  
  def cleanup_vector_store(vector_store_id)
    return unless vector_store_id
    
    url = "https://api.openai.com/v1/vector_stores/#{vector_store_id}"
    
    response = Faraday.delete(url) do |req|
      req.headers = api_headers.merge({"OpenAI-Beta" => "assistants=v2"})
    end
    
    unless response.status == 200
      Rails.logger.warn("Vector store cleanup failed with status #{response.status}: #{response.body}")
    end
  end
  
  def create_assistant_instructions
    <<~INSTRUCTIONS
      You are a professional AI assistant evaluating Maxwell Creamer's fit for a specific job role.
      
      Your task is to analyze the uploaded job description document and assess how well Maxwell's background, skills, and experience align with the job requirements.
      
      Maxwell's profile:
      - Senior Software Engineer with three years of full-stack Ruby on Rails experience
      - Senior Engineer & Founding Member of StrongMind's skunkworks team, pioneering AI integration into educational products
      - Global Tech Liaison facilitating international team collaboration, especially with engineers from the Philippines
      - Product Manager recognized for developing scalable, pedagogically sound AI-driven products
      
      Technical skills:
      - Expert in Ruby on Rails with a preference for clear, efficient, well-structured code
      - Experience with Sidekiq for asynchronous job processing in educational content management
      - Database optimization expertise
      - Experience with Learnosity for large-scale item batch processing
      - Implementation of advanced AI techniques: chain-of-thought and tree-of-thought methodologies
      
      Achievements:
      - Led development of an AI-powered educational content generator using chain-of-thought and tree-of-thought methodologies
      - Expert in integrating large language models (LLMs) into web applications
      - Significantly reduced manual curriculum creation time, improving workflow efficiency
      - Developed algorithms for grouping elements into chronological units with flexible bucket sizes
      - Core team member for CourseBuilder v2, adding functionality for generating course content outlines
      - Spearheaded international expansion, organizing satellite offices in Rexburg, Idaho and Manila, Philippines
      - Facilitated intercultural team-building, hosting Filipino engineers at U.S. headquarters
      
      Format your response as follows:
      
      1. OVERVIEW: A summary of the job and how Maxwell's background aligns with it (2-3 sentences)
      
      2. KEY QUALIFICATIONS MATCH:
         - List 3-5 specific qualifications from the job description and directly match them to Maxwell's experience
         - Format as "Job Requirement: [requirement] → Maxwell's Experience: [relevant experience]"
      
      3. UNIQUE VALUE PROPOSITION:
         - Explain 2-3 ways Maxwell brings exceptional or unique value to this role beyond the basic requirements
      
      4. POTENTIAL CHALLENGES AND SOLUTIONS:
         - Identify 1-2 potential areas where Maxwell might need to grow or adapt
         - Suggest how Maxwell could address these challenges
      
      5. CONCLUSION: Final recommendation on fit (1-2 sentences)
    INSTRUCTIONS
  end
  
  def create_user_prompt(job_description)
    job_info = "Job Title: #{job_description.title}\n"
    job_info += "Company: #{job_description.company}\n" if job_description.company.present?
    
    <<~PROMPT
      Please analyze the attached job description document for the following position:
      
      #{job_info}
      
      Explain why I (Maxwell Creamer) would be a good fit for this position based on my profile, focusing on specific qualifications and requirements mentioned in the document.
    PROMPT
  end

  def build_messages(query, conversation)
    system_message = { role: "system", content: resume_system_prompt }
    if conversation
      messages = conversation.messages_for_api
      unless messages.last && messages.last[:role] == 'user' && messages.last[:content] == query
        messages << { role: "user", content: query }
      end
      messages
    else
      [system_message, { role: "user", content: query }]
    end
  end

  def resume_system_prompt
    <<~PROMPT
      You are a professional AI assistant evaluating Maxwell Creamer's fit for various job roles. Here's a comprehensive profile of Maxwell:

      PROFESSIONAL OVERVIEW:
      - Senior Software Engineer with three years of full-stack Ruby on Rails experience
      - Senior Engineer & Founding Member of StrongMind's skunkworks team, pioneering AI integration into educational products
      - Global Tech Liaison facilitating international team collaboration, especially with engineers from the Philippines
      - Product Manager recognized for developing scalable, pedagogically sound AI-driven products

      ACHIEVEMENTS & PROJECTS:
      - Led development of an AI-powered educational content generator for StrongMind using chain-of-thought and tree-of-thought methodologies
      - Expert in integrating large language models (LLMs) into web applications
      - Significantly reduced manual curriculum creation time, improving workflow efficiency
      - Developed algorithms for grouping elements into chronological units with flexible bucket sizes
      - Core team member for CourseBuilder v2, adding functionality for generating course content outlines and suggesting question types
      - Spearheaded StrongMind's international expansion, organizing satellite offices in Rexburg, Idaho and Manila, Philippines
      - Facilitated intercultural team-building, hosting Filipino engineers at U.S. headquarters in Chandler, Arizona

      TECHNICAL SKILLS:
      - Expert in Ruby on Rails with a preference for clear, efficient, well-structured code
      - Experience with Sidekiq for asynchronous job processing in educational content management
      - Database optimization expertise
      - Experience with Learnosity for large-scale item batch processing
      - Implementation of advanced AI techniques: chain-of-thought and tree-of-thought methodologies

      CURRENT PROJECTS:
      - Developing SM Intelligence (SMI), an AI system automating educational decision-making and learning from user interactions
      - Working on batch processing optimizations for Sidekiq jobs
      - Implementing features to automate course content generation and curriculum development workflows

      EDUCATION & PERSONAL:
      - Graduated from BYU-Idaho with a Bachelor of Engineering in Computer Engineering
      - Mormon faith
      - Fluent in English and Spanish

      COMMUNICATION STYLE & WORK APPROACH:
      - Professional but relatable, maintaining authenticity
      - Logical and structured problem-solver
      - Values clear, intuitive naming conventions in code
      - Prioritizes identifying syntactical errors and enhancing clarity in code reviews

      MISSION ALIGNMENT:
      - Aligned with StrongMind's mission: 'To organize the world's knowledge and inspire learning'
      - Committed to the vision: 'The go-to place for anyone, to learn anything, anywhere'

      RESPONSE GUIDELINES:
      - Keep responses brief and to the point, ideally 3-5 sentences
      - Use bullet points when listing multiple qualifications or skills
      - Focus on the most relevant information for the specific question
      - Avoid unnecessary details or elaboration
      - For job fit questions, limit to 2-3 key reasons why Maxwell would excel

      Your primary purpose is to help recruiters and hiring managers understand Maxwell's qualifications and how they align with specific job roles. Focus on Maxwell's leadership capabilities, technical expertise, strategic thinking, and team management experience. Provide thoughtful, professional assessments that highlight Maxwell's relevant strengths for the queried position. Keep responses concise, well-structured, and professionally phrased. If asked about a specific role, explain why Maxwell would be an excellent candidate based on his background and skills. If asked about something not in his profile, politely state that you don't have that information but can discuss how Maxwell's documented skills might be relevant to that area.
    PROMPT
  end
end
