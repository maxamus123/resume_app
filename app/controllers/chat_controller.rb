class ChatController < ApplicationController
  protect_from_forgery with: :null_session, only: [:message]
  before_action :extract_question, only: [:message]

  def index
    # This action will render the chat interface
  end

  def message
    @response = if @question.present?
                  OpenaiService.new.resume_chat(@question)
                else
                  "Please ask a question about Maxwell's resume."
                end

    respond_to do |format|
      format.json { render json: { response: @response } }
      format.html { render plain: @response }
    end
  end

  private

  def extract_question
    params_json = if request.format.json?
                    JSON.parse(request.body.read) rescue {}
                  else
                    {}
                  end
    @question = params_json['question'] || params[:question]
  end
end
