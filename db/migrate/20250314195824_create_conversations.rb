class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.string :session_id, null: false, index: true
      t.string :identifier

      t.timestamps
    end
  end
end
