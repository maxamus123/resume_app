class CreateEducations < ActiveRecord::Migration[7.1]
  def change
    create_table :educations do |t|
      t.string :institution
      t.string :degree
      t.string :field
      t.date :start_date
      t.date :end_date
      t.string :gpa
      t.text :description

      t.timestamps
    end
  end
end
