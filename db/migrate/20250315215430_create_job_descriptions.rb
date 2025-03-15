class CreateJobDescriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :job_descriptions do |t|
      t.string :title
      t.string :company
      t.text :analysis
      t.string :session_id

      t.timestamps
    end
  end
end
