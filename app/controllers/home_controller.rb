class HomeController < ApplicationController
  def index
    @profile = Profile.first
    @experiences = Experience.order(end_date: :desc, start_date: :desc)
    @educations = Education.order(end_date: :desc)
    @skills = Skill.all.group_by(&:category)
    @languages = Language.all
  end
end
