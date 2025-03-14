require 'rails_helper'

RSpec.describe "Chat", type: :request do
  describe "GET /chat" do
    it "returns http success" do
      get "/chat"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /chat/message" do
    it "returns http success" do
      # Mock a valid message post
      post "/chat/message", params: { message: "What are your skills?" }
      expect(response).to have_http_status(:success)
    end
  end
  
  describe "GET /chat/stream_message" do
    it "returns http success" do
      get "/chat/stream_message"
      expect(response).to have_http_status(:success)
    end
  end
end
