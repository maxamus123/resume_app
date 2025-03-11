class CreateSolidCacheTables < ActiveRecord::Migration[8.0]
  def change
    load Rails.root.join("db/cache_schema.rb")
  end
end
