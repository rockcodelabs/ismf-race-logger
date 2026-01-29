# frozen_string_literal: true

class CreatePenalties < ActiveRecord::Migration[8.1]
  def change
    create_table :penalties do |t|
      t.string :category, null: false, limit: 1
      t.string :category_title, null: false
      t.text :category_description
      t.string :penalty_number, null: false
      t.string :name, null: false
      t.string :team_individual
      t.string :vertical
      t.string :sprint_relay
      t.text :notes

      t.timestamps

      t.index :category
      t.index :penalty_number, unique: true
    end
  end
end