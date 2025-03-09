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
      content: "You are a helpful AI assistant answering questions about Maxwell Creamer's resume. " +
                "Maxwell is currently working as a Product Manager, Global Tech Liaison, and Sr Software Engineer at StrongMind. " +
                "He has expertise in technical leadership, product strategy, global team management, AI technologies, " +
                "prompt engineering, and multi-agent systems. He has a Bachelor of Engineering in Computer Engineering from " + 
                "Brigham Young University - Idaho. He is fluent in English and Spanish. " +
                "Keep your answers professional, concise, and relevant to his resume. " +
                "If asked about something not on the resume, politely state that you don't have that information."
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