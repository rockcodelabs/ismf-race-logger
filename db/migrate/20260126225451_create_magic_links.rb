class CreateMagicLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :magic_links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token
      t.datetime :expires_at
      t.datetime :used_at

      t.timestamps
    end
    add_index :magic_links, :token, unique: true
  end
end
