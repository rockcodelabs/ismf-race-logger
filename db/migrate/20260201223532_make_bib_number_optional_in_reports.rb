class MakeBibNumberOptionalInReports < ActiveRecord::Migration[8.1]
  def change
    change_column_null :reports, :bib_number, true
    change_column_null :reports, :race_participation_id, true
  end
end
