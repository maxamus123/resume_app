class Language < ApplicationRecord
  # Returns a formatted display of the language name and proficiency
  def display_text
    "#{name} <span class='text-gray-600 ml-1 sm:ml-2 text-xs sm:text-sm'>#{proficiency}</span>"
  end
  
  # Returns HTML-safe formatted display text
  def display_html
    display_text.html_safe
  end
end
