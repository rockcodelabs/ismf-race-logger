# frozen_string_literal: true

module Structs
  # ExpensesJustification Struct
  #
  # Immutable domain object representing an expense reimbursement request
  # submitted by ISMF officials for competition-related travel and expenses.
  #
  # Workflow:
  #   1. User creates expense justification (status: draft)
  #   2. User submits for approval (status: sent)
  #   3. ISMF staff approves/rejects (status: approved/rejected)
  #   4. ISMF staff marks as paid (paid: true)
  #
  # Used for:
  # - Single expense justification detail views
  # - Expense justification show pages
  # - Approval/rejection workflow
  #
  class ExpensesJustification < DB::Struct
    attribute :id, Types::Integer
    attribute :user_id, Types::Integer
    attribute :competition_id, Types::Integer
    
    # Personal Information
    attribute :name, Types::String
    attribute :address, Types::String
    attribute :identity_document_number, Types::String
    
    # Bank Information
    attribute :bank_swift, Types::String
    attribute :bank_iban, Types::String
    
    # Trip Details
    attribute :reason_of_travel, Types::String
    attribute :charged_of, Types::String.optional
    attribute :place, Types::String.optional
    attribute :country, Types::String.optional
    attribute :travel_start_date, Types::Date
    attribute :travel_end_date, Types::Date
    attribute :travel_days, Types::Integer
    
    # Expense Line Items (JSONB)
    attribute :regular_transport, Types::Hash.optional.default({}.freeze)
    attribute :private_vehicle, Types::Hash.optional.default({}.freeze)
    attribute :car_rental, Types::Hash.optional.default({}.freeze)
    attribute :other_travelling, Types::Hash.optional.default({}.freeze)
    attribute :allowances, Types::Hash.optional.default({}.freeze)
    attribute :accommodation, Types::Hash.optional.default({}.freeze)
    attribute :special_expenses, Types::Hash.optional.default({}.freeze)
    
    # Totals
    attribute :total_amount, Types::Coercible::Decimal
    
    # Status & Workflow
    attribute :status, Types::ExpensesJustificationStatus
    attribute :paid, Types::Bool
    attribute :submitted_at, Types::OptionalDateTime
    attribute :approved_at, Types::OptionalDateTime
    attribute :rejected_at, Types::OptionalDateTime
    attribute :paid_at, Types::OptionalDateTime
    attribute :approved_by_id, Types::Integer.optional
    attribute :rejected_by_id, Types::Integer.optional
    attribute :rejection_reason, Types::String.optional
    
    attribute :created_at, Types::FlexibleDateTime
    attribute :updated_at, Types::FlexibleDateTime
    
    # Optional nested data (loaded via repo methods)
    attribute :user_name, Types::String.optional
    attribute :user_email, Types::String.optional
    attribute :competition_name, Types::String.optional
    attribute :approved_by_name, Types::String.optional
    attribute :rejected_by_name, Types::String.optional
    
    # Invoice attachments (array of ActiveStorage blobs)
    attribute :invoices, Types::Array.optional
    
    # Status helpers
    def draft?
      status == "draft"
    end
    
    def sent?
      status == "sent"
    end
    
    def approved?
      status == "approved"
    end
    
    def rejected?
      status == "rejected"
    end
    
    # Workflow checks
    def can_edit?
      draft?
    end
    
    def can_submit?
      draft?
    end
    
    def can_approve?
      sent?
    end
    
    def can_reject?
      sent?
    end
    
    def can_mark_as_paid?
      approved? && !paid?
    end
    
    def can_delete?
      draft?
    end
    
    # Display helpers
    def status_badge_class
      case status
      when "draft" then "bg-gray-100 text-gray-800"
      when "sent" then "bg-blue-100 text-blue-800"
      when "approved" then "bg-green-100 text-green-800"
      when "rejected" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    end
    
    def status_display
      case status
      when "draft" then "Draft"
      when "sent" then "Submitted"
      when "approved" then "Approved"
      when "rejected" then "Rejected"
      else status.titleize
      end
    end
    
    def paid_badge_class
      paid? ? "bg-green-100 text-green-800" : "bg-yellow-100 text-yellow-800"
    end
    
    def paid_display
      paid? ? "Paid" : "Unpaid"
    end
    
    # Travel period display
    def travel_period
      return "" if travel_start_date.nil? || travel_end_date.nil?
      
      if travel_start_date == travel_end_date
        travel_start_date.strftime("%d/%m/%Y")
      else
        "#{travel_start_date.strftime('%d/%m/%Y')} - #{travel_end_date.strftime('%d/%m/%Y')}"
      end
    end
    
    # Days calculation display
    def days_display
      "#{travel_days} day#{'s' unless travel_days == 1}"
    end
    
    # Total amount formatted
    def total_amount_display
      "€ #{format('%.2f', total_amount)}"
    end
    
    # Submission timestamp display
    def submitted_at_display
      submitted_at&.strftime("%d/%m/%Y %H:%M")
    end
    
    # Approval timestamp display
    def approved_at_display
      approved_at&.strftime("%d/%m/%Y %H:%M")
    end
    
    # Rejection timestamp display
    def rejected_at_display
      rejected_at&.strftime("%d/%m/%Y %H:%M")
    end
    
    # Payment timestamp display
    def paid_at_display
      paid_at&.strftime("%d/%m/%Y")
    end
  end
end