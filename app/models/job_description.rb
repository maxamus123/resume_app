class JobDescription < ApplicationRecord
  has_one_attached :document
  
  validates :title, presence: true
  validate :acceptable_document
  
  # For OpenAI multimodal analysis, we'll store the document's extracted text
  # and the AI-generated analysis
  
  private
  
  def acceptable_document
    return unless document.attached?
    
    # Validate file presence
    errors.add(:document, "must be attached") unless document.attached?
    
    # Validate file size
    errors.add(:document, "is too large (max 10MB)") if document.blob.byte_size > 10.megabytes
    
    # Validate content type
    acceptable_types = ["application/pdf", "application/msword", 
                        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                        "text/plain", "text/markdown"]
    
    unless acceptable_types.include?(document.content_type)
      errors.add(:document, "must be a PDF, Word document, or text file")
    end
  end
end
