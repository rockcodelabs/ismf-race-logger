class AddUniqueIndexToRacesPosition < ActiveRecord::Migration[8.1]
  def up
    # Remove existing non-unique index
    remove_index :races, name: "index_races_on_competition_id_and_position"
    
    # Fix duplicate positions by reassigning them sequentially within each competition
    execute <<-SQL
      WITH ranked_races AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY competition_id ORDER BY id) - 1 AS new_position
        FROM races
      )
      UPDATE races
      SET position = ranked_races.new_position
      FROM ranked_races
      WHERE races.id = ranked_races.id
    SQL
    
    # Add unique index to ensure each position is unique within a competition
    add_index :races, [:competition_id, :position], unique: true, name: "index_races_on_competition_id_and_position"
  end
  
  def down
    # Remove unique index
    remove_index :races, name: "index_races_on_competition_id_and_position"
    
    # Add back non-unique index
    add_index :races, [:competition_id, :position], name: "index_races_on_competition_id_and_position"
  end
end
