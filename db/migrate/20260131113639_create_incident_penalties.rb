# frozen_string_literal: true

# Join table for incidents and penalties (many-to-many)
# An incident can have multiple penalties attached
class CreateIncidentPenalties < ActiveRecord::Migration[8.0]
  def change
    create_table :incident_penalties do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :penalty, null: false, foreign_key: true

      t.timestamps
    end

    # Ensure each penalty can only be attached once per incident
    add_index :incident_penalties, %i[incident_id penalty_id], unique: true
  end
end