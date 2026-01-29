# frozen_string_literal: true

class CreateRaceTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :race_types do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :race_types, :name, unique: true
  end
end