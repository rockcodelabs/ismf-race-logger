# frozen_string_literal: true

class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      t.uuid :client_uuid, null: false
      t.references :race, null: false, foreign_key: true
      t.references :incident, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :race_location, null: false, foreign_key: true
      t.references :race_participation, null: false, foreign_key: true
      t.integer :bib_number, null: false
      t.integer :athlete_position
      t.text :description
      t.string :status, null: false, default: "pending_review"

      t.timestamps
    end

    add_index :reports, :client_uuid, unique: true
    add_index :reports, :status
    add_index :reports, :bib_number
  end
end