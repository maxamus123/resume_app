class ChatController < ApplicationController
  protect_from_forgery with: :null_session, only: [:message, :stream_message]
  include ActionController::Live
  
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
  
  def stream_message
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    
    # For GET requests, we'll be using params directly
    question = params[:question]
    
    if question.present?
      # Use OpenaiService class with streaming
      openai_service = OpenaiService.new
      
      # Write initial SSE event
      response.stream.write("event: start\ndata: {}\n\n")
      
      openai_service.stream_resume_chat(question) do |chunk|
        response.stream.write("event: message\ndata: #{chunk.to_json}\n\n")
      end
      
      # Write final SSE event
      response.stream.write("event: done\ndata: {}\n\n")
    else
      response.stream.write("event: error\ndata: #{JSON.generate({message: "Please ask a question about Maxwell's resume."})}\n\n")
    end
  rescue IOError, ActionController::Live::ClientDisconnected
    # Client disconnected
    Rails.logger.info "Client disconnected"
  ensure
    response.stream.close
  end
end
