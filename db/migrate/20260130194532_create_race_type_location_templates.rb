# frozen_string_literal: true

class CreateRaceTypeLocationTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :race_type_location_templates do |t|
      t.references :race_type, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :course_segment, null: false
      t.string :segment_position, null: false
      t.integer :display_order, null: false
      t.boolean :is_standard, null: false, default: false
      t.string :color_code
      t.text :description

      t.timestamps
    end

    add_index :race_type_location_templates, [:race_type_id, :display_order],
              name: "index_race_type_location_templates_on_type_and_order"
    add_index :race_type_location_templates, [:race_type_id, :name],
              name: "index_race_type_location_templates_on_type_and_name"
  end
end