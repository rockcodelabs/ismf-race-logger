# frozen_string_literal: true

class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.string :notable_type, null: false
      t.bigint :notable_id, null: false
      t.bigint :user_id, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :notes, [:notable_type, :notable_id]
    add_index :notes, :user_id
    add_foreign_key :notes, :users
  end
end