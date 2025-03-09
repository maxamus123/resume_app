class ChatController < ApplicationController
  protect_from_forgery with: :null_session, only: [:message]
  
  def index
    # This action will render the chat interface
  end

  def message
    # Get question from JSON params if available
    params_json = request.format.json? ? (JSON.parse(request.body.read) rescue nil) : nil
    question = params_json&.dig('question') || params[:question]
    
    if question.present?
      # Use OpenaiService class
      openai_service = OpenaiService.new
      @response = openai_service.resume_chat(question)
    else
      @response = "Please ask a question about Maxwell's resume."
    end
    
    respond_to do |format|
      format.json { render json: { response: @response } }
      format.html { render plain: @response }
    end
  end
end
