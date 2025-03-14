class ChatController < ApplicationController
  protect_from_forgery with: :null_session, only: [:message, :stream_message]
  include ActionController::Live

  def index; end

  def message
    question = extract_question_from_request
    return render_response("Please ask a question about Maxwell's resume.") if question.blank?

    conversation = find_or_initialize_conversation
    conversation.add_message('user', question)

    openai_service = OpenaiService.new
    answer = openai_service.resume_chat(question, conversation)
    conversation.add_message('assistant', answer)

    render_response(answer)
  end

  def stream_message
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'

    question = params[:question]
    unless question.present?
      response.stream.write("event: error\ndata: #{JSON.generate(message: "Please ask a question about Maxwell's resume.")}\n\n")
      return
    end

    conversation = find_or_initialize_conversation
    conversation.add_message('user', question)

    response.stream.write("event: start\ndata: {}\n\n")
    accumulated_response = ""
    openai_service = OpenaiService.new

    openai_service.stream_resume_chat(question, conversation) do |chunk|
      accumulated_response << chunk
      response.stream.write("event: message\ndata: #{chunk.to_json}\n\n")
    end

    conversation.add_message('assistant', accumulated_response)
    response.stream.write("event: done\ndata: {}\n\n")
  rescue IOError, ActionController::Live::ClientDisconnected
    Rails.logger.info "Client disconnected"
  ensure
    response.stream.close
  end

  private

  def extract_question_from_request
    data = request.format.json? ? (JSON.parse(request.body.read) rescue {}) : {}
    data['question'] || params[:question]
  end

  def find_or_initialize_conversation
    conversation = Conversation.find_or_create_for_session(session.id.to_s)
    if conversation.messages.empty?
      conversation.add_message('system', OpenaiService.new.send(:resume_system_prompt))
    end
    conversation
  end

  def render_response(message)
    respond_to do |format|
      format.json { render json: { response: message } }
      format.html { render plain: message }
    end
  end
end
