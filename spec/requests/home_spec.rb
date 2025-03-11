require 'rails_helper'

RSpec.describe "Home", type: :request do
  describe "GET /resume" do
    it "returns http success" do
      get "/resume"
      expect(response).to have_http_status(:success)
    end

    it "assigns the necessary instance variables" do
      profile = create(:profile)
      skills = create_list(:skill, 3)
      experiences = create_list(:experience, 2)
      educations = create_list(:education, 1)
      languages = create_list(:language, 2)

      get "/resume"
      
      expect(assigns(:profile)).to eq(profile)
      expect(assigns(:skills)).to be_a(Hash)
      expect(assigns(:experiences)).to be_an(ActiveRecord::Relation)
      expect(assigns(:educations)).to be_an(ActiveRecord::Relation)
      expect(assigns(:languages)).to be_an(ActiveRecord::Relation)
    end
  end

  describe "GET /" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:success)
    end

    it "renders with the side_by_side layout" do
      get "/"
      expect(response).to render_template('side_by_side')
    end

    it "assigns the necessary instance variables" do
      profile = create(:profile)
      skills = create_list(:skill, 3)
      experiences = create_list(:experience, 2)
      educations = create_list(:education, 1)
      languages = create_list(:language, 2)

      get "/"
      
      expect(assigns(:profile)).to eq(profile)
      expect(assigns(:skills)).to be_a(Hash)
      expect(assigns(:experiences)).to be_an(ActiveRecord::Relation)
      expect(assigns(:educations)).to be_an(ActiveRecord::Relation)
      expect(assigns(:languages)).to be_an(ActiveRecord::Relation)
    end
  end
end
