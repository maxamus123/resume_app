class CreateLanguages < ActiveRecord::Migration[7.1]
  def change
    create_table :languages do |t|
      t.string :name
      t.string :proficiency

      t.timestamps
    end
  end
end
