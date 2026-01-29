# frozen_string_literal: true

class CreateRaceParticipations < ActiveRecord::Migration[8.1]
  def change
    create_table :race_participations do |t|
      t.references :race, null: false, foreign_key: true
      t.references :athlete, null: false, foreign_key: true
      t.references :team, null: true, foreign_key: true
      t.integer :bib_number, null: false
      t.string :heat
      t.boolean :active_in_heat, default: true
      t.string :status, default: "registered"
      t.datetime :start_time
      t.datetime :finish_time
      t.integer :rank

      t.timestamps
    end

    add_index :race_participations, [:race_id, :bib_number], unique: true
    add_index :race_participations, [:race_id, :athlete_id], unique: true
    add_index :race_participations, :status
    add_index :race_participations, :heat
  end
end