class Experience < ApplicationRecord
  # Default scope to order by end date and start date in descending order
  default_scope -> { order(end_date: :desc, start_date: :desc) }

  # Returns a formatted date range string
  def date_range
    start_formatted = start_date.strftime("%m/%Y")
    end_formatted = current? ? "Present" : end_date.strftime("%m/%Y")
    
    "#{start_formatted} - #{end_formatted}"
  end
  
  # Returns true if this is a current position
  def current?
    self.current
  end
  
  # Returns the duration of the experience in months
  def duration_in_months
    end_date_to_use = current? ? Date.today : end_date
    months = (end_date_to_use.year * 12 + end_date_to_use.month) - 
             (start_date.year * 12 + start_date.month)
    months
  end
  
  # Returns a human-readable duration string
  def duration_text
    months = duration_in_months
    years = months / 12
    remaining_months = months % 12
    
    if years > 0 && remaining_months > 0
      "#{years} year#{'s' if years > 1} #{remaining_months} month#{'s' if remaining_months > 1}"
    elsif years > 0
      "#{years} year#{'s' if years > 1}"
    else
      "#{months} month#{'s' if months > 1}"
    end
  end
end
