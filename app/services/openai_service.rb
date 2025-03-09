class OpenaiService
  attr_reader :client

  def initialize
    @api_key = ENV['OPENAI_ACCESS_TOKEN']
  end

  def chat(messages, max_tokens: 500)
    url = "https://api.openai.com/v1/chat/completions"
    
    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@api_key}"
    }
    
    payload = {
      model: "gpt-3.5-turbo",
      messages: messages,
      max_tokens: max_tokens
    }
    
    Rails.logger.info("Making API request to OpenAI with payload: #{payload.to_json}")
    
    response = Faraday.post(url) do |req|
      req.headers = headers
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
  
  def resume_chat(query)
    system_message = {
      role: "system", 
      content: "You are a professional AI assistant evaluating Maxwell Creamer's fit for various job roles. " +
                "Maxwell is currently working as a Product Manager, Global Tech Liaison, and Sr Software Engineer at StrongMind. " +
                "He has expertise in technical leadership, product strategy, global team management, AI technologies, " +
                "prompt engineering, and multi-agent systems. He has a Bachelor of Engineering in Computer Engineering from " + 
                "Brigham Young University - Idaho. He is fluent in English and Spanish. " +
                "Your primary purpose is to help recruiters and hiring managers understand Maxwell's qualifications and " +
                "how they align with specific job roles. Focus on Maxwell's leadership capabilities, technical expertise, " +
                "strategic thinking, and team management experience. " +
                "Provide thoughtful, professional assessments that highlight Maxwell's relevant strengths for the queried position. " +
                "If asked about a specific role, explain why Maxwell would be an excellent candidate for that position. " +
                "Keep responses concise, well-structured, and professionally phrased. " +
                "If asked about something not on the resume, politely state that you don't have that information but can " +
                "discuss how Maxwell's documented skills might be relevant to that area."
    }
    
    user_message = { role: "user", content: query }
    
    response = chat([system_message, user_message])
    
    if response["choices"] && response["choices"].first && response["choices"].first["message"]
      response["choices"].first["message"]["content"]
    elsif response["error"]
      "Error: #{response["error"]}"
    else
      "I'm sorry, I encountered an error processing your request."
    end
  end
end 