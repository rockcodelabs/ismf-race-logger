# frozen_string_literal: true

# ExpensesJustificationBroadcaster - Real-time Turbo Stream broadcasts for expenses justifications
#
# Handles broadcasting expense justification changes to:
# - Admin stream: All ISMF staff see all updates
# - User stream: Individual users see updates to their own expenses
#
# Example:
#   broadcaster = AppContainer["broadcasters.expenses_justification"]
#   broadcaster.submitted(record)      # Notify staff of new submission
#   broadcaster.approved(record)       # Notify user of approval
#   broadcaster.rejected(record)       # Notify user of rejection
#   broadcaster.marked_as_paid(record) # Update payment status
#
class ExpensesJustificationBroadcaster < BaseBroadcaster
  # Broadcast when a new expense justification is submitted
  # Notifies ISMF staff of new submission
  def submitted(expenses_justification)
    # Broadcast to admin stream (all ISMF staff)
    broadcast_prepend(
      admin_stream_name,
      target: "expenses_justifications_pending",
      partial: "admin/expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )

    # Broadcast to user stream (submitter)
    broadcast_update(
      user_stream_name(expenses_justification.user_id),
      target: dom_id(expenses_justification),
      partial: "expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )
  end

  # Broadcast when an expense justification is approved
  # Notifies user and updates admin list
  def approved(expenses_justification)
    # Broadcast to admin stream
    broadcast_replace(
      admin_stream_name,
      target: dom_id(expenses_justification),
      partial: "admin/expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )

    # Broadcast to user stream
    broadcast_update(
      user_stream_name(expenses_justification.user_id),
      target: dom_id(expenses_justification),
      partial: "expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )
  end

  # Broadcast when an expense justification is rejected
  # Notifies user and updates admin list
  def rejected(expenses_justification)
    # Broadcast to admin stream
    broadcast_replace(
      admin_stream_name,
      target: dom_id(expenses_justification),
      partial: "admin/expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )

    # Broadcast to user stream
    broadcast_update(
      user_stream_name(expenses_justification.user_id),
      target: dom_id(expenses_justification),
      partial: "expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )
  end

  # Broadcast when an expense justification is marked as paid
  # Updates both admin and user views
  def marked_as_paid(expenses_justification)
    # Broadcast to admin stream
    broadcast_replace(
      admin_stream_name,
      target: dom_id(expenses_justification),
      partial: "admin/expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )

    # Broadcast to user stream
    broadcast_update(
      user_stream_name(expenses_justification.user_id),
      target: dom_id(expenses_justification),
      partial: "expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )
  end

  # Broadcast when an expense justification is created (draft)
  # Only broadcasts to user stream
  def created(expenses_justification)
    broadcast_prepend(
      user_stream_name(expenses_justification.user_id),
      target: "expenses_justifications",
      partial: "expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )
  end

  # Broadcast when an expense justification is updated
  # Only broadcasts to user stream (drafts don't appear in admin view)
  def updated(expenses_justification)
    broadcast_update(
      user_stream_name(expenses_justification.user_id),
      target: dom_id(expenses_justification),
      partial: "expenses_justifications/expenses_justification",
      struct: expenses_justification,
      as: :expenses_justification
    )
  end

  # Broadcast when an expense justification is deleted
  # Removes from both streams
  def deleted(expenses_justification)
    # Remove from admin stream
    broadcast_remove(
      admin_stream_name,
      target: dom_id(expenses_justification)
    )

    # Remove from user stream
    broadcast_remove(
      user_stream_name(expenses_justification.user_id),
      target: dom_id(expenses_justification)
    )
  end

  private

  # Stream name for admin (ISMF staff) - all expenses justifications
  # Clients subscribe with: turbo_stream_from "expenses_justifications"
  def admin_stream_name
    "expenses_justifications"
  end

  # Stream name for specific user - only their expenses justifications
  # Clients subscribe with: turbo_stream_from "expenses_justifications:user_123"
  def user_stream_name(user_id)
    "expenses_justifications:user_#{user_id}"
  end

  # DOM ID for targeting specific expense justifications
  def dom_id(expenses_justification)
    if expenses_justification.is_a?(ExpensesJustification)
      "expenses_justification_#{expenses_justification.id}"
    else
      "expenses_justification_#{expenses_justification.id}"
    end
  end
end