require 'securerandom'

class OpenaiService
  API_URL = "https://api.openai.com/v1/chat/completions".freeze

  def initialize
    @api_key = ENV.fetch('OPENAI_ACCESS_TOKEN')
  end

  def chat(messages, max_tokens: 4000)
    payload = { model: "gpt-4-turbo", messages: messages, max_tokens: max_tokens }
    log_info("Sending payload: #{payload.to_json}")
    response = Faraday.post(API_URL) do |req|
      req.headers = api_headers
      req.body = payload.to_json
    end
    log_info("Response: #{response.status} - #{response.body}")
    parse_response(response)
  rescue Faraday::Error => e
    log_error(e.message)
    { "error" => e.message }
  end

  def stream_chat(messages, max_tokens: 4000)
    payload = { model: "gpt-4-turbo", messages: messages, max_tokens: max_tokens, stream: true }
    log_info("Starting streaming request")
    accumulated_text = ""
    conn = Faraday.new { |f| f.response :raise_error }
    conn.post(API_URL) do |req|
      req.headers = api_headers
      req.body = payload.to_json
      req.options.on_data = Proc.new do |chunk, _|
        chunk.each_line do |line|
          next unless line.start_with?('data: ') && !line.include?('data: [DONE]')
          data = line.sub('data: ', '')
          begin
            parsed = JSON.parse(data)
            if (delta = parsed.dig('choices', 0, 'delta', 'content'))
              accumulated_text << delta
              yield delta if block_given?
            end
          rescue JSON::ParserError => e
            log_error("JSON parse error: #{e.message}")
          end
        end
      end
    end
    accumulated_text
  rescue Faraday::Error => e
    log_error(e.message)
    yield "Error: #{e.message}" if block_given?
    "Error: #{e.message}"
  end

  def resume_chat(query, conversation = nil)
    messages = build_messages(query, conversation)
    response = chat(messages)
    response.dig("choices", 0, "message", "content") || "Error: #{response['error'] || 'Unknown error'}"
  end

  def stream_resume_chat(query, conversation = nil, &block)
    messages = build_messages(query, conversation)
    stream_chat(messages, &block)
  end

  # If a document is attached, delegate the analysis to the AssistantService.
  def analyze_job_fit(job_description)
    if job_description.document.attached?
      log_info("Using assistant analysis for document")
      AssistantService.new.analyze_job_description(job_description)
    else
      log_info("Using standard chat for job description")
      prompt = job_description_analysis_prompt(job_description)
      messages = [
        { role: "system", content: prompt },
        { role: "user", content: "Please analyze this job description and tell me why I would be a good fit based on my profile." }
      ]
      response = chat(messages, max_tokens: 4000)
      response.dig("choices", 0, "message", "content") || "Sorry, I couldn't analyze this job description. Please try again."
    end
  end

  def job_description_analysis_prompt(job_description)
    job_info = "Job Title: #{job_description.title}\n"
    job_info += "Company: #{job_description.company}\n" if job_description.company.present?
    <<~PROMPT
      You are a professional AI assistant evaluating Maxwell Creamer's fit for a specific job role.

      JOB DETAILS:
      #{job_info}

      MAXWELL'S PROFILE:
      - Senior Software Engineer with Ruby on Rails expertise
      - Proven leadership and innovation in AI integration

      Format your response as:
      1. OVERVIEW
      2. KEY QUALIFICATIONS MATCH
      3. UNIQUE VALUE PROPOSITION
      4. POTENTIAL CHALLENGES AND SOLUTIONS
      5. CONCLUSION
    PROMPT
  end

  def build_messages(query, conversation)
    system_message = { role: "system", content: resume_system_prompt }
    if conversation
      messages = conversation.messages_for_api
      messages << { role: "user", content: query } if messages.last[:content] != query
      messages
    else
      [system_message, { role: "user", content: query }]
    end
  end

  def resume_system_prompt
    <<~PROMPT
      You are a professional AI assistant evaluating Maxwell Creamer's fit for various job roles.
      PROFESSIONAL OVERVIEW:
      - Senior Software Engineer with full-stack Ruby on Rails experience
      - Experience in AI integration and international team collaboration
      - Proven leadership in product management and innovation
    PROMPT
  end

  def api_headers
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{@api_key}" }
  end

  def parse_response(response)
    if response.status == 200
      JSON.parse(response.body)
    else
      log_error("API error #{response.status}: #{response.body}")
      { "error" => "API request failed with status #{response.status}: #{response.body}" }
    end
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
