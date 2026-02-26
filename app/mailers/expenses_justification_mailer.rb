# frozen_string_literal: true

# ExpensesJustificationMailer
#
# Sends email notifications for expenses justification workflow:
# - submitted: Notifies ISMF staff when a user submits an expense justification
# - approved: Notifies user when their expense justification is approved
# - rejected: Notifies user when their expense justification is rejected (includes reason)
#
class ExpensesJustificationMailer < ApplicationMailer
  # Notify ISMF staff that a new expense justification has been submitted
  #
  # @param expenses_justification [ExpensesJustification]
  def submitted(expenses_justification)
    @expenses_justification = expenses_justification
    @user = expenses_justification.user
    @competition = expenses_justification.competition

    # Get all ISMF staff emails
    ismf_staff_role = Role.find_by(name: "ismf_staff")
    staff_emails = ismf_staff_role&.users&.pluck(:email_address) || []

    return if staff_emails.empty?

    mail(
      to: staff_emails,
      subject: "New Expense Justification Submitted - #{@user.display_name}"
    )
  end

  # Notify user that their expense justification has been approved
  #
  # @param expenses_justification [ExpensesJustification]
  def approved(expenses_justification)
    @expenses_justification = expenses_justification
    @user = expenses_justification.user
    @competition = expenses_justification.competition
    @approved_by = expenses_justification.approved_by

    mail(
      to: @user.email_address,
      subject: "Expense Justification Approved - #{@competition.name}"
    )
  end

  # Notify user that their expense justification has been rejected
  #
  # @param expenses_justification [ExpensesJustification]
  def rejected(expenses_justification)
    @expenses_justification = expenses_justification
    @user = expenses_justification.user
    @competition = expenses_justification.competition
    @rejected_by = expenses_justification.rejected_by
    @rejection_reason = expenses_justification.rejection_reason

    mail(
      to: @user.email_address,
      subject: "Expense Justification Rejected - #{@competition.name}"
    )
  end
end