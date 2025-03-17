module ApplicationHelper
  def section_heading(title, options = {})
    css = options[:class] || "text-lg sm:text-xl font-bold text-gray-800 border-b-2 border-teal-200 pb-2 mb-3 sm:mb-4"
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
    css = options[:class] || "bg-slate-100 rounded-lg px-2 sm:px-3 py-1"
    content_tag(:div, class: css) do
      content_tag(:span, text, class: "font-medium text-xs sm:text-sm")
    end
  end

  def render_if_present(content)
    capture { yield } if content.present?
  end

  def markdown(text)
    return "" if text.blank?
    
    # Use the simplest CommonMarker call possible
    result = CommonMarker.render_html(text)
    
    # Add additional CSS classes to the generated HTML
    result = result.gsub(/<h(\d)>/, '<h\1 class="text-gray-900 font-bold">')
                .gsub(/<table>/, '<table class="border-collapse border border-gray-300 my-4 w-full">')
                .gsub(/<th>/, '<th class="border border-gray-300 bg-gray-100 p-2">')
                .gsub(/<td>/, '<td class="border border-gray-300 p-2">')
                .gsub(/<pre>/, '<pre class="bg-gray-100 p-4 rounded overflow-auto my-4">')
                .gsub(/<code>/, '<code class="bg-gray-100 px-1 py-0.5 rounded text-sm">')
                .gsub(/<blockquote>/, '<blockquote class="border-l-4 border-gray-300 pl-4 italic my-4">')
                .gsub(/<a /, '<a class="text-teal-600 hover:text-teal-800 underline" ')
    
    sanitize_config = Rails::Html::SafeListSanitizer.allowed_tags + %w[sup sub blockquote hr]
    
    sanitize(result, tags: sanitize_config).html_safe
  end
end
