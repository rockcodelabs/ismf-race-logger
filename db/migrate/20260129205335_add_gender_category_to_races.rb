# frozen_string_literal: true

class AddGenderCategoryToRaces < ActiveRecord::Migration[8.1]
  def change
    add_column :races, :gender_category, :string, null: false, default: "M"
    add_index :races, :gender_category
  end
end
