module ApplicationHelper
  # Generate section heading with consistent styling
  def section_heading(title, options = {})
    css_class = options[:class] || "text-lg sm:text-xl font-bold text-gray-800 border-b-2 border-blue-200 pb-2 mb-3 sm:mb-4"
    content_tag(:h2, title, class: css_class)
  end

  # Generate subsection heading with consistent styling
  def subsection_heading(title, options = {})
    css_class = options[:class] || "text-base sm:text-lg font-semibold text-gray-800 mb-2"
    content_tag(:h3, title, class: css_class)
  end
  
  # Generate a responsive layout class for container elements
  def responsive_container_class(options = {})
    base = options[:base] || "mb-4 sm:mb-5"
    "#{base} #{options[:additional]}"
  end
  
  # Format a date range with consistent styling
  def format_date_range(start_date, end_date, is_current = false)
    start_str = start_date.strftime("%m/%Y")
    end_str = is_current ? "Present" : end_date.strftime("%m/%Y")
    "#{start_str} - #{end_str}"
  end
  
  # Generate HTML for a badge/tag style element
  def badge_tag(text, options = {})
    css_class = options[:class] || "bg-gray-100 rounded-lg px-2 sm:px-3 py-1"
    content_tag(:div, class: css_class) do
      content_tag(:span, text, class: "font-medium text-xs sm:text-sm")
    end
  end
  
  # Helper to conditionally render content only if it exists
  def render_if_present(content, &block)
    return unless content.present?
    
    capture(&block)
  end
end
