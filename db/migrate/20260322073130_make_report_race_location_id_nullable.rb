# frozen_string_literal: true

class MakeReportRaceLocationIdNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :reports, :race_location_id, true
  end
end