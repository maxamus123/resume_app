require 'rails_helper'

RSpec.describe "Chat", type: :request do
  describe "GET /chat" do
    it "returns http success" do
      get "/chat"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /chat/message" do
    let(:openai_service) { instance_double(OpenaiService) }
    let(:question) { "What are Maxwell's skills?" }
    let(:ai_response) { "Maxwell is skilled in Ruby on Rails, AI integration, and team leadership." }

    before do
      allow(OpenaiService).to receive(:new).and_return(openai_service)
      allow(openai_service).to receive(:resume_chat).with(question).and_return(ai_response)
    end

    context "with JSON format" do
      it "returns the AI response as JSON" do
        post "/chat/message", params: { question: question }, as: :json
        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "response" => ai_response })
      end

      it "handles JSON in request body" do
        post "/chat/message", 
             params: { question: question }.to_json, 
             headers: { "CONTENT_TYPE" => "application/json" }
        expect(response).to have_http_status(:success)
        expect(response.body).to eq(ai_response)
      end

      it "returns an error message when no question is provided" do
        post "/chat/message", as: :json
        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)["response"]).to match(/Please .* question/)
      end
    end

    context "with HTML format" do
      it "returns the AI response as plain text" do
        post "/chat/message", params: { question: question }
        expect(response).to have_http_status(:success)
        expect(response.body).to eq(ai_response)
      end

      it "returns an error message when no question is provided" do
        post "/chat/message"
        expect(response).to have_http_status(:success)
        expect(response.body).to match(/Please .* question/)
      end
    end

    context "when OpenAI service returns an error" do
      let(:error_message) { "Error: OpenAI API unavailable" }
      
      before do
        allow(openai_service).to receive(:resume_chat).with(question).and_return(error_message)
      end

      it "returns the error message in JSON format" do
        post "/chat/message", params: { question: question }, as: :json
        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "response" => error_message })
      end

      it "returns the error message in HTML format" do
        post "/chat/message", params: { question: question }
        expect(response).to have_http_status(:success)
        expect(response.body).to eq(error_message)
      end
    end
  end

  describe "question extraction" do
    let(:openai_service) { instance_double(OpenaiService) }
    
    before do
      allow(OpenaiService).to receive(:new).and_return(openai_service)
    end
    
    it "extracts question from params" do
      allow(openai_service).to receive(:resume_chat).with("test question").and_return("test question response")
      post "/chat/message", params: { question: "test question" }
      expect(response).to have_http_status(:success)
      expect(response.body).to eq("test question response")
    end

    it "extracts question from JSON body" do
      allow(openai_service).to receive(:resume_chat).with("json question").and_return("json question response")
      post "/chat/message", 
           params: { question: "json question" }.to_json, 
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:success)
      expect(response.body).to eq("json question response")
    end
  end
end
