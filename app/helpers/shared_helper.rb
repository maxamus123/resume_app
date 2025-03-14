module SharedHelper
  # Returns an SVG icon for a contact method
  def contact_icon(contact_type, options = {})
    css_class = options[:class] || "h-4 w-4 sm:h-5 sm:w-5 mr-1 sm:mr-2"
    
    case contact_type.to_sym
    when :email
      <<-SVG.html_safe
        <svg xmlns="http://www.w3.org/2000/svg" class="#{css_class}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        </svg>
      SVG
    when :phone
      <<-SVG.html_safe
        <svg xmlns="http://www.w3.org/2000/svg" class="#{css_class}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
        </svg>
      SVG
    when :linkedin
      <<-SVG.html_safe
        <svg xmlns="http://www.w3.org/2000/svg" class="#{css_class}" fill="currentColor" viewBox="0 0 24 24">
          <path d="M19 0h-14c-2.761 0-5 2.239-5 5v14c0 2.761 2.239 5 5 5h14c2.762 0 5-2.239 5-5v-14c0-2.761-2.238-5-5-5zm-11 19h-3v-11h3v11zm-1.5-12.268c-.966 0-1.75-.79-1.75-1.764s.784-1.764 1.75-1.764 1.75.79 1.75 1.764-.783 1.764-1.75 1.764zm13.5 12.268h-3v-5.604c0-3.368-4-3.113-4 0v5.604h-3v-11h3v1.765c1.396-2.586 7-2.777 7 2.476v6.759z"/>
        </svg>
      SVG
    when :github
      <<-SVG.html_safe
        <svg xmlns="http://www.w3.org/2000/svg" class="#{css_class}" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
        </svg>
      SVG
    else
      ""
    end
  end

  # Renders a contact information item with icon
  def contact_item(profile, contact_type, options = {})
    return unless profile.contact_info[contact_type].present?
    
    item_class = options[:item_class] || "flex items-center mr-4 sm:mr-6 mb-2"
    text_class = options[:text_class] || "text-sm sm:text-base text-teal-100 hover:text-white transition duration-150"
    
    content_tag(:div, class: item_class) do
      icon = contact_icon(contact_type, class: options[:icon_class])
      
      case contact_type
      when :email
        icon + link_to(profile.email, "mailto:#{profile.email}", class: text_class)
      when :phone
        icon + link_to(profile.phone, "tel:#{profile.phone}", class: text_class)
      when :linkedin
        icon + link_to("LinkedIn", profile.linkedin, target: "_blank", rel: "noopener noreferrer", class: text_class)
      when :github
        icon + link_to("GitHub", profile.github, target: "_blank", rel: "noopener noreferrer", class: text_class)
      end
    end
  end
  
  # Renders a skill with tooltip showing proficiency
  def skill_tag(skill, options = {})
    item_class = options[:item_class] || "px-3 py-2 sm:px-4 sm:py-2"
    
    content_tag(:div, class: "group relative bg-gray-100 hover:bg-gray-200 rounded-lg transition duration-200 border-b-2 border-teal-600") do
      inner = content_tag(:div, class: item_class) do
        content_tag(:span, skill.name, class: "font-medium text-xs sm:text-sm")
      end
      
      tooltip = content_tag(:div, class: "absolute z-10 left-1/2 transform -translate-x-1/2 bottom-full mb-1 invisible group-hover:visible bg-teal-600 text-white text-xs rounded py-1 px-2 whitespace-nowrap shadow-lg") do
        # Create the tooltip content
        tooltip_text = content_tag(:span, skill.proficiency_tooltip)
        
        # Create the arrow separately
        arrow = content_tag(:div, "", class: "absolute top-full left-1/2 transform -translate-x-1/2 w-2 h-2 rotate-45 bg-teal-600")
        
        # Combine them in safe HTML
        tooltip_text + arrow
      end
      
      inner + tooltip
    end
  end
  
  # Renders all skills grouped by category
  def skills_section(skills_by_category, options = {})
    container_class = options[:container_class] || "mb-5 sm:mb-6" 
    
    capture do
      skills_by_category.each do |category, skills|
        concat(content_tag(:div, class: container_class) do
          subtitle = subsection_heading(category, class: options[:subtitle_class])
          
          skills_container = content_tag(:div, class: "flex flex-wrap gap-2 sm:gap-3") do
            skills.map { |skill| skill_tag(skill, options) }.join.html_safe
          end
          
          subtitle + skills_container
        end)
      end
    end
  end
end 