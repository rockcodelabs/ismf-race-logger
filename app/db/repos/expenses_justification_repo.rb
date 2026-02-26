# frozen_string_literal: true

# ExpensesJustificationRepo
#
# Repository for expenses justifications (expense reimbursement requests).
# Provides query methods for retrieving and managing expense justifications.
#
# Returns:
# - Single records: Structs::ExpensesJustification (full struct)
# - Collections: Structs::ExpensesJustificationSummary (for lists)
#
# Usage:
#   repo = AppContainer["repos.expenses_justification"]
#   repo.all                            # => [Structs::ExpensesJustificationSummary, ...]
#   repo.for_user(user_id)              # => [Structs::ExpensesJustificationSummary, ...]
#   repo.for_competition(competition_id)# => [Structs::ExpensesJustificationSummary, ...]
#   repo.by_status(status)              # => [Structs::ExpensesJustificationSummary, ...]
#   repo.pending_approval               # => [Structs::ExpensesJustificationSummary, ...]
#   repo.approved_unpaid                # => [Structs::ExpensesJustificationSummary, ...]
#   repo.find(id)                       # => Structs::ExpensesJustification or nil
#
class ExpensesJustificationRepo < DB::Repo
  self.record_class = ExpensesJustification
  self.struct_class = Structs::ExpensesJustification
  self.summary_class = Structs::ExpensesJustificationSummary

  returns_one :find, :find!
  returns_many :all, :for_user, :for_competition, :by_status, :pending_approval,
               :approved_unpaid, :recent

  # Get all expense justifications, ordered by most recent first
  # @return [Array<Structs::ExpensesJustificationSummary>]
  def all
    ExpensesJustification
      .includes(:user, :competition)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get all expense justifications for a specific user
  # @param user_id [Integer]
  # @return [Array<Structs::ExpensesJustificationSummary>]
  def for_user(user_id)
    ExpensesJustification
      .where(user_id: user_id)
      .includes(:user, :competition)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get all expense justifications for a specific competition
  # @param competition_id [Integer]
  # @return [Array<Structs::ExpensesJustificationSummary>]
  def for_competition(competition_id)
    ExpensesJustification
      .where(competition_id: competition_id)
      .includes(:user, :competition)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get expense justifications by status
  # @param status [String] One of: draft, sent, approved, rejected
  # @return [Array<Structs::ExpensesJustificationSummary>]
  def by_status(status)
    ExpensesJustification
      .where(status: status)
      .includes(:user, :competition)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get expense justifications pending approval (status: sent)
  # @return [Array<Structs::ExpensesJustificationSummary>]
  def pending_approval
    by_status("sent")
  end

  # Get approved but unpaid expense justifications
  # @return [Array<Structs::ExpensesJustificationSummary>]
  def approved_unpaid
    ExpensesJustification
      .where(status: "approved", paid: false)
      .includes(:user, :competition)
      .order(approved_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get recent expense justifications across all users (for admin dashboard)
  # @param limit [Integer]
  # @return [Array<Structs::ExpensesJustificationSummary>]
  def recent(limit = 20)
    ExpensesJustification
      .includes(:user, :competition)
      .order(created_at: :desc)
      .limit(limit)
      .map { |record| build_summary(record) }
  end

  # Count expense justifications by status
  # @return [Hash] e.g., { "draft" => 5, "sent" => 3, "approved" => 10, "rejected" => 2 }
  def count_by_status
    ExpensesJustification.group(:status).count
  end

  # Count approved but unpaid expense justifications
  # @return [Integer]
  def count_approved_unpaid
    ExpensesJustification.where(status: "approved", paid: false).count
  end

  protected

  def base_scope
    ExpensesJustification
      .includes(:user, :competition, :approved_by, :rejected_by, invoices_attachments: :blob)
  end

  def build_struct(record)
    record = record.is_a?(ExpensesJustification) ? record : base_scope.find(record)

    Structs::ExpensesJustification.new(
      id: record.id,
      user_id: record.user_id,
      competition_id: record.competition_id,
      name: record.name,
      address: record.address,
      identity_document_number: record.identity_document_number,
      bank_swift: record.bank_swift,
      bank_iban: record.bank_iban,
      reason_of_travel: record.reason_of_travel,
      charged_of: record.charged_of,
      place: record.place,
      country: record.country,
      travel_start_date: record.travel_start_date,
      travel_end_date: record.travel_end_date,
      travel_days: record.travel_days,
      regular_transport: record.regular_transport || {},
      private_vehicle: record.private_vehicle || {},
      car_rental: record.car_rental || {},
      other_travelling: record.other_travelling || {},
      allowances: record.allowances || {},
      accommodation: record.accommodation || {},
      special_expenses: record.special_expenses || {},
      total_amount: record.total_amount,
      status: record.status,
      paid: record.paid,
      submitted_at: record.submitted_at,
      approved_at: record.approved_at,
      rejected_at: record.rejected_at,
      paid_at: record.paid_at,
      approved_by_id: record.approved_by_id,
      rejected_by_id: record.rejected_by_id,
      rejection_reason: record.rejection_reason,
      created_at: record.created_at,
      updated_at: record.updated_at,
      user_name: record.user&.name,
      user_email: record.user&.email_address,
      competition_name: record.competition&.name,
      approved_by_name: record.approved_by&.name,
      rejected_by_name: record.rejected_by&.name,
      invoices: record.invoices.attached? ? record.invoices.blobs.to_a : []
    )
  end

  def build_summary(record)
    Structs::ExpensesJustificationSummary.new(
      id: record.id,
      user_id: record.user_id,
      competition_id: record.competition_id,
      name: record.name,
      reason_of_travel: record.reason_of_travel,
      travel_start_date: record.travel_start_date,
      travel_end_date: record.travel_end_date,
      travel_days: record.travel_days,
      total_amount: record.total_amount,
      status: record.status,
      paid: record.paid,
      submitted_at: record.submitted_at,
      approved_at: record.approved_at,
      rejected_at: record.rejected_at,
      rejection_reason: record.rejection_reason,
      created_at: record.created_at,
      updated_at: record.updated_at,
      user_name: record.user&.name,
      user_email: record.user&.email_address,
      competition_name: record.competition&.name,
      invoices_count: record.invoices.attached? ? record.invoices.count : 0
    )
  end
end