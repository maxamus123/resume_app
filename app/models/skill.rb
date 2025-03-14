class Skill < ApplicationRecord
  # Scopes
  scope :by_category, -> { order(:category, :name) }
  
  # Returns all skills grouped by category
  def self.grouped_by_category
    by_category.group_by(&:category)
  end
  
  # Returns proficiency as a string representation
  def proficiency_text
    "#{proficiency}/5"
  end
  
  # Returns a CSS class based on proficiency level
  def proficiency_class
    case proficiency
    when 5 then 'expert'
    when 4 then 'advanced'
    when 3 then 'intermediate'
    else 'beginner'
    end
  end
  
  # Returns formatted tooltip text for proficiency
  def proficiency_tooltip
    "Proficiency: #{proficiency_text}"
  end
end
