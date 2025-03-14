class Profile < ApplicationRecord
  # Returns a hash of contact information that's present
  def contact_info
    {
      email: email.presence,
      phone: phone.presence,
      linkedin: linkedin.presence,
      github: github.presence
    }.compact
  end
  
  # Returns true if any contact information is available
  def has_contact_info?
    contact_info.any?
  end
  
  # Returns a formatted representation of the full name and title
  def full_title
    [name, title].compact.join(', ')
  end
end
