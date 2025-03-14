class HomeController < ApplicationController
  def index
    @profile = Profile.first
    @skills = Skill.grouped_by_category
    @experiences = Experience.all # Using default scope
    @educations = Education.all # Using default scope
    @languages = Language.all
  end
  
  def interactive
    @profile = Profile.first
    @skills = Skill.grouped_by_category
    @experiences = Experience.all # Using default scope
    @educations = Education.all # Using default scope
    @languages = Language.all
    
    render layout: 'side_by_side'
  end
end
