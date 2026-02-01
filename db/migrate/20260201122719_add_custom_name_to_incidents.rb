class AddCustomNameToIncidents < ActiveRecord::Migration[8.1]
  def change
    add_column :incidents, :custom_name, :string
  end
end
