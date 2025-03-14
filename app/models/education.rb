class Education < ApplicationRecord
  # Default scope to order by end date in descending order
  default_scope -> { order(end_date: :desc) }
  
  # Returns a formatted date range string (years only)
  def year_range
    return nil unless start_date.present? && end_date.present?
    
    "#{start_date.strftime('%Y')} - #{end_date.strftime('%Y')}"
  end
  
  # Returns a formatted degree and field
  def degree_with_field
    return degree unless field.present?
    
    "#{degree} in #{field}"
  end
  
  # Returns a formatted GPA string if present
  def formatted_gpa
    return nil unless gpa.present?
    
    "GPA: #{gpa}"
  end
  
  # Returns true if this education entry has dates
  def has_dates?
    start_date.present? && end_date.present?
  end
  
  # Returns true if this education entry has a description
  def has_description?
    description.present?
  end
end
