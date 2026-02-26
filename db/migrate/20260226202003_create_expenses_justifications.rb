# frozen_string_literal: true

class CreateExpensesJustifications < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses_justifications do |t|
      # References
      t.references :user, null: false, foreign_key: true  # created_by
      t.references :competition, null: false, foreign_key: true

      # Personal Information
      t.string :name, null: false
      t.text :address, null: false
      t.string :identity_document_number, null: false

      # Bank Information
      t.string :bank_swift, null: false
      t.string :bank_iban, null: false

      # Trip Details
      t.string :reason_of_travel, null: false  # Race name/meeting
      t.string :charged_of  # Role: VAR Referee, etc.
      t.string :place
      t.string :country
      t.date :travel_start_date, null: false
      t.date :travel_end_date, null: false
      t.integer :travel_days, null: false

      # Expense Line Items (JSONB for flexibility)
      t.jsonb :regular_transport, default: {}
      t.jsonb :private_vehicle, default: {}
      t.jsonb :car_rental, default: {}
      t.jsonb :other_travelling, default: {}
      t.jsonb :allowances, default: {}
      t.jsonb :accommodation, default: {}
      t.jsonb :special_expenses, default: {}

      # Totals
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0.0

      # Status & Workflow
      t.string :status, null: false, default: "draft"  # draft, sent, approved, rejected
      t.boolean :paid, default: false, null: false
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :rejected_at
      t.datetime :paid_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.references :rejected_by, foreign_key: { to_table: :users }
      t.text :rejection_reason

      t.timestamps
    end

    # Indexes
    add_index :expenses_justifications, :status
    add_index :expenses_justifications, :paid
    add_index :expenses_justifications, [:user_id, :status]
    add_index :expenses_justifications, [:competition_id, :status]
  end
end
