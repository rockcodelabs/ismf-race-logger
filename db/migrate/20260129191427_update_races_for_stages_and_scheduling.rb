# frozen_string_literal: true

class UpdateRacesForStagesAndScheduling < ActiveRecord::Migration[8.1]
  def change
    # Rename start_time to scheduled_at and make it nullable
    rename_column :races, :start_time, :scheduled_at
    change_column_null :races, :scheduled_at, true
    
    # Split stage into stage_type and heat_number
    add_column :races, :stage_type, :string
    add_column :races, :heat_number, :integer
    
    # Backfill stage_type from existing stage column
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE races SET stage_type = stage WHERE stage IS NOT NULL
        SQL
      end
    end
    
    # Make stage_type NOT NULL after backfill
    change_column_null :races, :stage_type, false
    
    # Add stage_name as computed/cached field for display
    # This will store the combined "Stage Type" or "Stage Type Heat#"
    add_column :races, :stage_name, :string
    
    # Backfill stage_name from stage_type
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE races SET stage_name = stage_type WHERE stage_type IS NOT NULL
        SQL
      end
    end
    
    # Make stage_name NOT NULL after backfill
    change_column_null :races, :stage_name, false
    
    # Remove old stage column
    remove_column :races, :stage, :string
    
    # Index on scheduled_at already exists from the rename_column operation
    # No need to add it again
  end
end