require 'rails_helper'

RSpec.describe "Educations", type: :request do
  describe "GET /educations" do
    it "returns http success" do
      get "/educations"
      expect(response).to have_http_status(:success)
    end
  end

end
