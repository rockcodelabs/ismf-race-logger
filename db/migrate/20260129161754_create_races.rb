# frozen_string_literal: true

class CreateRaces < ActiveRecord::Migration[8.1]
  def change
    create_table :races do |t|
      t.references :competition, null: false, foreign_key: true
      t.references :race_type, null: false, foreign_key: true
      
      t.string :name, null: false
      t.string :stage, null: false
      t.datetime :start_time, null: false
      t.integer :position, null: false, default: 0
      t.string :status, null: false, default: "scheduled"
      
      t.timestamps
    end

    add_index :races, [:competition_id, :position]
    add_index :races, :status
    add_index :races, :start_time
  end
end