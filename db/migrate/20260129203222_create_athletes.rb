# frozen_string_literal: true

class CreateAthletes < ActiveRecord::Migration[8.1]
  def change
    create_table :athletes do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :country, limit: 3, null: false
      t.string :license_number
      t.string :gender, limit: 1, null: false

      t.timestamps
    end

    add_index :athletes, [:first_name, :last_name, :gender, :country], name: "index_athletes_on_name_gender_country"
    add_index :athletes, :license_number, unique: true, where: "license_number IS NOT NULL"
    add_index :athletes, :country
  end
end