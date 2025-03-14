require 'rails_helper'

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "returns http success for interactive view" do
      get "/"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /resume" do
    it "returns http success for standard resume view" do
      get "/resume"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /resume.pdf" do
    it "returns http success for PDF download" do
      get "/resume.pdf"
      expect(response).to have_http_status(:success)
    end
  end
end
