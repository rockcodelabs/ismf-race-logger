# frozen_string_literal: true

module Web
  module Parts
    # Presentation logic for ExpensesJustification
    #
    # Parts wrap structs with view-specific logic. They:
    # - Keep structs pure (domain only)
    # - Keep templates simple (no inline logic)
    # - Are testable in isolation
    # - Delegate missing methods to the wrapped struct
    #
    # @example
    #   part = Web::Parts::ExpensesJustification.new(struct)
    #   part.status_badge      # => presentation logic
    #   part.name              # => delegates to struct
    #   part.dom_id            # => "expenses_justification_123"
    #
    class ExpensesJustification < Base
      # Status badge with appropriate styling
      def status_badge
        helpers.tag.span(value.status_display, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{value.status_badge_class}")
      end

      # Paid/unpaid badge
      def paid_badge
        helpers.tag.span(value.paid_display, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{value.paid_badge_class}")
      end

      # Full status display with both status and paid badges
      def full_status_badges
        helpers.safe_join([status_badge, " ", paid_badge].compact)
      end

      # Formatted travel period
      def travel_period_display
        helpers.tag.div(class: "text-sm text-gray-600") do
          helpers.concat helpers.tag.span("📅 ", class: "mr-1")
          helpers.concat value.travel_period
          helpers.concat " "
          helpers.concat helpers.tag.span("(#{value.days_display})", class: "text-gray-500")
        end
      end

      # Formatted total amount with currency
      def total_amount_badge
        helpers.tag.span(value.total_amount_display, class: "inline-flex items-center px-3 py-1 rounded-md text-sm font-semibold bg-blue-50 text-blue-700")
      end

      # Competition name with link
      def competition_link
        if value.competition_name.present?
          helpers.link_to(value.competition_name, helpers.competition_path(value.competition_id), class: "text-blue-600 hover:text-blue-800 font-medium")
        else
          helpers.tag.span("Unknown Competition", class: "text-gray-400")
        end
      end

      # User name display
      def user_display
        if value.user_name.present?
          helpers.tag.div(class: "flex items-center") do
            helpers.concat helpers.tag.span("👤 ", class: "mr-1")
            helpers.concat value.user_name
          end
        else
          helpers.tag.span("Unknown User", class: "text-gray-400")
        end
      end

      # Bank account display (masked for security)
      def bank_account_display
        if value.bank_iban.present?
          masked_iban = "****#{value.bank_iban.last(4)}"
          helpers.tag.div(class: "text-sm") do
            helpers.concat helpers.tag.div("IBAN: #{masked_iban}", class: "font-mono text-gray-700")
            helpers.concat helpers.tag.div("SWIFT: #{value.bank_swift}", class: "font-mono text-gray-600 text-xs") if value.bank_swift.present?
          end
        else
          helpers.tag.span("Not provided", class: "text-gray-400 text-sm")
        end
      end

      # Timeline display for workflow
      def timeline_display
        helpers.tag.div(class: "space-y-2 text-sm") do
          # Created
          helpers.concat helpers.tag.div(class: "flex items-center text-gray-600") do
            helpers.concat helpers.tag.span("📝 ", class: "mr-2")
            helpers.concat "Created: #{value.created_at.strftime('%d/%m/%Y %H:%M')}"
          end

          # Submitted
          if value.submitted_at.present?
            helpers.concat helpers.tag.div(class: "flex items-center text-blue-600") do
              helpers.concat helpers.tag.span("📤 ", class: "mr-2")
              helpers.concat "Submitted: #{value.submitted_at_display}"
            end
          end

          # Approved
          if value.approved_at.present?
            helpers.concat helpers.tag.div(class: "flex items-center text-green-600") do
              helpers.concat helpers.tag.span("✅ ", class: "mr-2")
              helpers.concat "Approved: #{value.approved_at_display}"
              if value.approved_by_name.present?
                helpers.concat helpers.tag.span(" by #{value.approved_by_name}", class: "text-gray-600")
              end
            end
          end

          # Rejected
          if value.rejected_at.present?
            helpers.concat helpers.tag.div(class: "flex items-center text-red-600") do
              helpers.concat helpers.tag.span("❌ ", class: "mr-2")
              helpers.concat "Rejected: #{value.rejected_at_display}"
              if value.rejected_by_name.present?
                helpers.concat helpers.tag.span(" by #{value.rejected_by_name}", class: "text-gray-600")
              end
            end
          end

          # Paid
          if value.paid_at.present?
            helpers.concat helpers.tag.div(class: "flex items-center text-green-600") do
              helpers.concat helpers.tag.span("💰 ", class: "mr-2")
              helpers.concat "Paid: #{value.paid_at_display}"
            end
          end
        end
      end

      # Rejection reason display
      def rejection_reason_display
        return nil unless value.rejected? && value.rejection_reason.present?

        helpers.tag.div(class: "mt-4 p-4 bg-red-50 border border-red-200 rounded-md") do
          helpers.concat helpers.tag.h4("Rejection Reason:", class: "text-sm font-semibold text-red-800 mb-2")
          helpers.concat helpers.tag.p(value.rejection_reason, class: "text-sm text-red-700")
        end
      end

      # Invoice count badge
      def invoice_count_badge
        # Handle both summary structs (invoices_count) and full structs (invoices)
        count = if value.respond_to?(:invoices_count)
                  value.invoices_count
                elsif value.respond_to?(:invoices)
                  value.invoices&.count || 0
                else
                  0
                end
        
        if count > 0
          helpers.tag.span(class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-700") do
            helpers.concat "📎 "
            helpers.concat "#{count} invoice#{'s' unless count == 1}"
          end
        else
          helpers.tag.span("No invoices", class: "text-xs text-gray-400")
        end
      end

      # Action buttons data - returns hash indicating which actions are available
      # View should handle actual rendering
      def action_buttons(current_user:, policy:)
        {
          can_update: policy.update?,
          can_submit: policy.submit?,
          can_destroy: policy.destroy?
        }
      end

      # Admin action buttons data - returns hash indicating which actions are available
      # View should handle actual rendering
      def admin_action_buttons(policy:)
        {
          can_approve: policy.approve?,
          can_reject: policy.reject?,
          can_mark_as_paid: policy.mark_as_paid?
        }
      end

      # DOM ID for Turbo Streams
      def dom_id
        "expenses_justification_#{value.id}"
      end

      # Created at formatted
      def created_at_formatted
        value.created_at.strftime("%B %d, %Y at %H:%M")
      end

      # Time ago helper
      def time_ago
        helpers.time_ago_in_words(value.created_at) + " ago"
      end
    end
  end
end