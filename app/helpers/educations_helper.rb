module EducationsHelper
  # Render an education entry
  def education_entry(education, options = {})
    container_class = options[:container_class] || "mb-4 sm:mb-5"
    
    content_tag(:div, class: container_class) do
      # Header with degree, institution, and date range
      header = content_tag(:div, class: "flex flex-col md:flex-row md:justify-between md:items-start") do
        # Degree and institution
        degree_div = content_tag(:div) do
          title = content_tag(:h3, education.degree_with_field, class: "text-base sm:text-lg font-semibold text-gray-800")
          institution = content_tag(:p, education.institution, class: "text-teal-600 font-medium text-sm sm:text-base")
          title + institution
        end
        
        # Date range
        date_div = if education.has_dates?
                     content_tag(:div, education.year_range, class: "text-amber-600 text-sm mt-1 md:mt-0 md:text-right")
                   else
                     "".html_safe
                   end
        
        degree_div + date_div
      end
      
      # GPA if present
      gpa = if education.formatted_gpa
              content_tag(:p, education.formatted_gpa, class: "text-gray-700 text-sm mt-1")
            else
              "".html_safe
            end
      
      # Description if present
      description = if education.has_description?
                      content_tag(:div, class: "mt-2 text-sm sm:text-base text-gray-700") do
                        simple_format(education.description)
                      end
                    else
                      "".html_safe
                    end
      
      header + gpa + description
    end
  end
  
  # Render all educations
  def render_educations(educations, options = {})
    capture do
      educations.each do |education|
        concat education_entry(education, options)
      end
    end
  end
end
