require 'rails_helper'

RSpec.describe "JobDescriptions", type: :request do
  describe "GET /upload" do
    it "returns http success" do
      get "/job_descriptions/upload"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /analyze" do
    it "returns http success" do
      get "/job_descriptions/analyze"
      expect(response).to have_http_status(:success)
    end
  end

end
