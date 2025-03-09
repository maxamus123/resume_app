class HomeController < ApplicationController
  def index
    @profile = Profile.first
    @skills = Skill.all.group_by(&:category)
    @experiences = Experience.order(end_date: :desc, start_date: :desc)
    @educations = Education.order(end_date: :desc)
    @languages = Language.all
  end
  
  def interactive
    @profile = Profile.first
    @skills = Skill.all.group_by(&:category)
    @experiences = Experience.order(end_date: :desc, start_date: :desc)
    @educations = Education.order(end_date: :desc)
    @languages = Language.all
    
    render layout: 'side_by_side'
  end
end
