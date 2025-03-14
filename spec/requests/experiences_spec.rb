require 'rails_helper'

RSpec.describe "Experiences", type: :request do
  describe "GET /experiences" do
    it "returns http success" do
      get "/experiences"
      expect(response).to have_http_status(:success)
    end
  end

end
