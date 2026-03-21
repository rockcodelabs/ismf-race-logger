# frozen_string_literal: true

# Repository for Note data access
#
# Handles polymorphic notes attached to Reports or Incidents.
#
# Example:
#   repo = NoteRepo.new
#   repo.for_notable("Report", 29)  # => [Structs::Note, ...]
#   repo.find(1)                     # => Structs::Note
#
class NoteRepo < DB::Repo
  returns_one :find
  returns_many :for_notable

  # Get all notes for a polymorphic notable (Report or Incident)
  #
  # @param notable_type [String] "Report" or "Incident"
  # @param notable_id [Integer]
  # @return [Array<Structs::Note>]
  def for_notable(notable_type, notable_id)
    base_scope
      .includes(:user)
      .where(notable_type: notable_type, notable_id: notable_id)
      .order(created_at: :asc)
      .map { |record| build_struct(record) }
  end

  protected

  def record_class
    Note
  end

  def base_scope
    Note.all
  end

  def build_struct(record)
    user_name = if record.association(:user).loaded? && record.user
      record.user.name.presence || record.user.email_address
    elsif record.user_id
      user = User.find_by(id: record.user_id)
      user&.name.presence || user&.email_address
    end

    Structs::Note.new(
      id: record.id,
      notable_type: record.notable_type,
      notable_id: record.notable_id,
      user_id: record.user_id,
      body: record.body,
      created_at: record.created_at,
      updated_at: record.updated_at,
      user_name: user_name
    )
  end

  def build_summary(record)
    build_struct(record)
  end
end