module ApplicationHelper
  def section_heading(title, options = {})
    css = options[:class] || "text-lg sm:text-xl font-bold text-gray-800 border-b-2 border-blue-200 pb-2 mb-3 sm:mb-4"
    content_tag(:h2, title, class: css)
  end

  def subsection_heading(title, options = {})
    css = options[:class] || "text-base sm:text-lg font-semibold text-gray-800 mb-2"
    content_tag(:h3, title, class: css)
  end

  def responsive_container_class(options = {})
    "#{options[:base] || 'mb-4 sm:mb-5'} #{options[:additional]}"
  end

  def format_date_range(start_date, end_date, current = false)
    "#{start_date.strftime('%m/%Y')} - #{current ? 'Present' : end_date.strftime('%m/%Y')}"
  end

  def badge_tag(text, options = {})
    css = options[:class] || "bg-gray-100 rounded-lg px-2 sm:px-3 py-1"
    content_tag(:div, class: css) do
      content_tag(:span, text, class: "font-medium text-xs sm:text-sm")
    end
  end

  def render_if_present(content)
    capture { yield } if content.present?
  end
end
