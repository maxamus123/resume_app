module ExperiencesHelper
  # Render an experience entry
  def experience_entry(experience, options = {})
    container_class = options[:container_class] || "mb-4 sm:mb-5"
    
    content_tag(:div, class: container_class) do
      # Header with position, company, and date range
      header = content_tag(:div, class: "flex flex-col md:flex-row md:justify-between md:items-start") do
        # Position and company
        position_div = content_tag(:div) do
          title = content_tag(:h3, experience.position, class: "text-base sm:text-lg font-semibold text-gray-800")
          company = content_tag(:p, experience.company, class: "text-teal-600 font-medium text-sm sm:text-base")
          title + company
        end
        
        # Date range
        date_div = content_tag(:div, experience.date_range, class: "text-amber-600 text-sm mt-1 md:mt-0 md:text-right")
        
        position_div + date_div
      end
      
      # Description
      description = content_tag(:div, class: "mt-2 text-sm sm:text-base text-gray-700") do
        simple_format(experience.description)
      end
      
      header + description
    end
  end
  
  # Render all experiences
  def render_experiences(experiences, options = {})
    capture do
      experiences.each do |experience|
        concat experience_entry(experience, options)
      end
    end
  end
end
