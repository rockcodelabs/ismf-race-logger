# frozen_string_literal: true

# ExpensesJustification model (associations only)
#
# Represents an expense reimbursement request submitted by ISMF officials
# for competition-related travel and expenses.
#
# Workflow:
# 1. User creates expense justification (status: draft)
# 2. User submits for approval (status: sent)
# 3. ISMF staff approves/rejects (status: approved/rejected)
# 4. ISMF staff marks as paid (paid: true)
#
# Business logic lives in:
# - Operations: app/operations/expenses_justifications/
# - Repo: app/db/repos/expenses_justification_repo.rb
# - Struct: app/db/structs/expenses_justification.rb
#
class ExpensesJustification < ApplicationRecord
  belongs_to :user
  belongs_to :competition
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :rejected_by, class_name: "User", optional: true

  # Invoice attachments (multiple files per justification)
  has_many_attached :invoices

  # Encrypt sensitive bank information
  encrypts :bank_swift
  encrypts :bank_iban
end