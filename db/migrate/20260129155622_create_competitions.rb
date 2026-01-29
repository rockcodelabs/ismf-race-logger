# frozen_string_literal: true

class CreateCompetitions < ActiveRecord::Migration[8.1]
  def change
    create_table :competitions do |t|
      t.string :name, null: false
      t.string :city, null: false
      t.string :place, null: false
      t.string :country, limit: 3, null: false
      t.text :description, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :webpage_url, null: false

      t.timestamps
    end

    add_index :competitions, :start_date
    add_index :competitions, :country
    add_index :competitions, [:start_date, :end_date]
  end
end