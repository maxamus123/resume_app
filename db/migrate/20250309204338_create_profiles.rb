class CreateProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :profiles do |t|
      t.string :name
      t.string :title
      t.text :summary
      t.string :phone
      t.string :email
      t.string :linkedin
      t.string :github
      t.string :website

      t.timestamps
    end
  end
end
