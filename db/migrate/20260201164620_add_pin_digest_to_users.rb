class AddPinDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pin_digest, :string
  end
end
