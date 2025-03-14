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
      # Find or create conversation for this session
      conversation = Conversation.find_or_create_for_session(session.id.to_s)
      
      # Add system message if this is a new conversation (no messages yet)
      if conversation.messages.empty?
        conversation.add_message('system', OpenaiService.new.send(:resume_system_prompt))
      end
      
      # Store the user's question
      conversation.add_message('user', question)
      
      # Use OpenaiService class with conversation history
      openai_service = OpenaiService.new
      @response = openai_service.resume_chat(question, conversation)
      
      # Store the assistant's response
      conversation.add_message('assistant', @response)
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
      # Find or create conversation for this session
      conversation = Conversation.find_or_create_for_session(session.id.to_s)
      
      # Add system message if this is a new conversation (no messages yet)
      if conversation.messages.empty?
        conversation.add_message('system', OpenaiService.new.send(:resume_system_prompt))
      end
      
      # Store the user's question
      conversation.add_message('user', question)
      
      # Use OpenaiService class with streaming and conversation history
      openai_service = OpenaiService.new
      
      # Write initial SSE event
      response.stream.write("event: start\ndata: {}\n\n")
      
      accumulated_response = ""
      
      openai_service.stream_resume_chat(question, conversation) do |chunk|
        accumulated_response += chunk
        response.stream.write("event: message\ndata: #{chunk.to_json}\n\n")
      end
      
      # Store the assistant's complete response
      conversation.add_message('assistant', accumulated_response)
      
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
