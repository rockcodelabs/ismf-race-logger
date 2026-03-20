# frozen_string_literal: true

class AddIsTestToRaces < ActiveRecord::Migration[8.1]
  def change
    add_column :races, :is_test, :boolean, default: false, null: false
  end
end