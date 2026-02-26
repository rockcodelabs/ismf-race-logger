# frozen_string_literal: true

class AddExpenseProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :full_name, :string
    add_column :users, :address, :text
    add_column :users, :identity_document_number, :string
    add_column :users, :bank_swift, :string
    add_column :users, :bank_iban, :string
    add_column :users, :country, :string
  end
end
