require 'rails_helper'

RSpec.describe "Skills", type: :request do
  describe "GET /skills" do
    it "returns http success" do
      get "/skills"
      expect(response).to have_http_status(:success)
    end
  end

end
