class HomeController < ApplicationController
  before_action :set_resources, only: [:index, :interactive]

  def index
  end

  def interactive
    render layout: 'side_by_side'
  end

  private

  def set_resources
    @profile = Profile.first
    @skills = Skill.all.group_by(&:category)
    @experiences = Experience.order(end_date: :desc, start_date: :desc)
    @educations = Education.order(end_date: :desc)
    @languages = Language.all
  end
end
