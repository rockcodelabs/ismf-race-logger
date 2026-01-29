# frozen_string_literal: true

class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.references :race, null: false, foreign_key: true
      t.integer :bib_number, null: false
      t.bigint :athlete_1_id, null: false
      t.bigint :athlete_2_id
      t.string :team_type, null: false
      t.string :name

      t.timestamps
    end

    add_foreign_key :teams, :athletes, column: :athlete_1_id
    add_foreign_key :teams, :athletes, column: :athlete_2_id

    add_index :teams, [:race_id, :bib_number], unique: true
    add_index :teams, :athlete_1_id
    add_index :teams, :athlete_2_id
  end
end