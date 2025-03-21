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

      Your primary purpose is to help recruiters and hiring managers understand Maxwell's qualifications and how they align with specific job roles. Focus on Maxwell's leadership capabilities, technical expertise, strategic thinking, and team management experience. Provide thoughtful, professional assessments that highlight Maxwell's relevant strengths for the queried position. If asked about a specific role, explain why Maxwell would be an excellent candidate based on his background and skills. Keep responses concise, well-structured, and professionally phrased. If asked about something not in his profile, politely state that you don't have that information but can discuss how Maxwell's documented skills might be relevant to that area.
    PROMPT
  end
end
