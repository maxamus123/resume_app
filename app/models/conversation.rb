class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy
  
  validates :session_id, presence: true
  
  MAX_MESSAGES = 50 # Maximum number of messages to keep (excluding system message)
  # Set a token limit that's safe for GPT-4 Turbo (which has ~128k token limit)
  MAX_TOKENS = 100_000 # Leave some headroom for the response
  
  # Find or create a conversation for a session
  def self.find_or_create_for_session(session_id)
    find_or_create_by(session_id: session_id)
  end
  
  # Add a new message to the conversation
  def add_message(role, content)
    messages.create(role: role, content: content)
    
    # Check both message count and token count
    trim_conversation_by_count if messages.count > MAX_MESSAGES + 1 # +1 for system message
    trim_conversation_by_tokens if estimated_token_count > MAX_TOKENS
  end
  
  # Get all messages formatted for OpenAI API
  def messages_for_api
    messages.order(:created_at).map do |message|
      { role: message.role, content: message.content }
    end
  end
  
  # Estimate the token count of the entire conversation
  # This is an approximation - OpenAI counts tokens differently
  # but this gives us a reasonable estimate
  def estimated_token_count
    # System message has extra overhead
    system_overhead = 200
    
    # For each message, we add some overhead for the role and format
    per_message_overhead = 4
    
    # Get all message contents
    all_content = messages.pluck(:content).join(' ')
    
    # Roughly estimate tokens (1 token ≈ 4 chars in English)
    content_tokens = all_content.size / 4
    
    # Add overheads
    message_format_tokens = messages.count * per_message_overhead
    
    system_message_tokens = messages.exists?(role: 'system') ? system_overhead : 0
    
    # Total estimated tokens
    content_tokens + message_format_tokens + system_message_tokens
  end
  
  private
  
  # Trim the conversation if it gets too long by message count
  # Always keep the system message and the most recent messages
  def trim_conversation_by_count
    system_message = messages.find_by(role: 'system')
    
    if system_message
      # Keep system message and the most recent MAX_MESSAGES messages
      messages_to_keep = messages.order(created_at: :desc).limit(MAX_MESSAGES).pluck(:id)
      messages_to_keep << system_message.id
      
      # Delete messages that are not in the keep list
      messages.where.not(id: messages_to_keep).destroy_all
    else
      # If no system message, just keep the most recent MAX_MESSAGES messages
      messages_to_delete = messages.order(created_at: :asc).offset(MAX_MESSAGES)
      messages_to_delete.destroy_all
    end
  end
  
  # Trim the conversation based on token count
  # We remove older messages until we're under the token limit
  def trim_conversation_by_tokens
    system_message = messages.find_by(role: 'system')
    
    # Get non-system messages in order (oldest first)
    msgs = messages.where.not(id: system_message&.id).order(created_at: :asc)
    
    # Remove oldest messages until we're under the token limit
    while msgs.any? && estimated_token_count > MAX_TOKENS
      oldest = msgs.first
      oldest.destroy
      msgs = msgs.where.not(id: oldest.id)
    end
  end
end
