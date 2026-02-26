# frozen_string_literal: true

module Structs
  # ExpensesJustificationSummary
  #
  # Lightweight immutable representation for expense justification collections.
  # Used for list views where full expense details are not needed.
  #
  # Used for:
  # - Index pages (user and admin)
  # - Filtered lists by status
  # - Dashboard summaries
  #
  ExpensesJustificationSummary = Data.define(
    :id,
    :user_id,
    :competition_id,
    :name,
    :reason_of_travel,
    :travel_start_date,
    :travel_end_date,
    :travel_days,
    :total_amount,
    :status,
    :paid,
    :submitted_at,
    :approved_at,
    :rejected_at,
    :rejection_reason,
    :created_at,
    :updated_at,
    # Optional nested data
    :user_name,
    :user_email,
    :competition_name,
    :invoices_count
  ) do
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

    def paid?
      paid
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
      paid ? "bg-green-100 text-green-800" : "bg-yellow-100 text-yellow-800"
    end

    def paid_display
      paid ? "Paid" : "Unpaid"
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

    # Total amount formatted
    def total_amount_display
      "€ #{format('%.2f', total_amount)}"
    end

    # Submitted timestamp display
    def submitted_at_display
      submitted_at&.strftime("%d/%m/%Y")
    end

    # Days calculation display
    def days_display
      "#{travel_days} day#{'s' unless travel_days == 1}"
    end
  end
end