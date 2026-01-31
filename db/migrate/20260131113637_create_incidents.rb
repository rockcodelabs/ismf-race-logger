# frozen_string_literal: true

class CreateIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :incidents do |t|
      t.uuid :client_uuid, null: false
      t.references :race, null: false, foreign_key: true
      t.references :race_location, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.text :description
      t.references :decided_by_user, foreign_key: { to_table: :users }
      t.datetime :decided_at

      t.timestamps
    end

    add_index :incidents, :client_uuid, unique: true
    add_index :incidents, :status
  end
end