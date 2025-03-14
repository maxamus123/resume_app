module ChatHelper
  # Generate a message bubble for the chat interface
  def chat_message(sender, content, options = {})
    sender_class = sender.downcase == 'ai assistant' ? 'text-teal-800' : 'text-gray-800'
    bg_class = sender.downcase == 'ai assistant' ? 'bg-teal-50' : 'bg-gray-100'
    
    content_tag(:div, class: "#{bg_class} p-2 sm:p-3 rounded-lg #{options[:additional_classes]}") do
      sender_element = content_tag(:p, sender, class: "font-medium #{sender_class} text-sm sm:text-base")
      content_element = content_tag(:p, content, class: "text-sm sm:text-base")
      sender_element + content_element
    end
  end
  
  # Generate a suggested question button
  def suggested_question_button(question_text, options = {})
    button_class = options[:class] || "suggested-question min-w-full px-2 py-1.5 sm:px-3 sm:py-2 text-xs sm:text-sm bg-gray-50 hover:bg-gray-100 text-gray-700 rounded-md transition-colors text-left"
    
    button_tag(question_text, type: "button", class: button_class)
  end
  
  # Generate carousel navigation buttons
  def carousel_nav_button(direction, options = {})
    direction_class = direction == 'prev' ? 'carousel-prev' : 'carousel-next'
    
    svg_path = if direction == 'prev'
                 "M15 19l-7-7 7-7"
               else
                 "M9 5l7 7-7 7"
               end
               
    button_tag(class: "#{direction_class} text-gray-500 hover:text-gray-700") do
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", class: "h-4 w-4", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor") do
        content_tag(:path, nil, 'stroke-linecap': "round", 'stroke-linejoin': "round", 'stroke-width': "2", d: svg_path)
      end
    end
  end
  
  # Generate a carousel indicator dot
  def carousel_dot(active: false, options: {})
    active_class = active ? 'bg-teal-600' : 'bg-gray-300'
    css_class = "carousel-dot h-1.5 w-1.5 sm:h-2 sm:w-2 rounded-full #{active_class}"
    
    content_tag(:span, nil, class: css_class)
  end
  
  # Generate carousel indicators for a given number of items
  def carousel_indicators(total, active_index = 0)
    content_tag(:div, class: "carousel-indicators flex space-x-2") do
      (0...total).map do |i|
        carousel_dot(active: i == active_index)
      end.join.html_safe
    end
  end
end
