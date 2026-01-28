# frozen_string_literal: true

# SessionRepo - Repository for Session data access (Hanami-style)
#
# This is the public interface for session persistence.
# All query logic lives here, NOT in the Session model.
# Returns structs (immutable data objects), not ActiveRecord models.
#
# Example:
#   repo = SessionRepo.new
#
#   session = repo.find(1)                    # => SessionStruct or nil
#   session = repo.create(user_id: 1, ...)    # => SessionStruct or nil
#   sessions = repo.for_user(user_id)         # => [SessionSummary, ...]
#
class SessionRepo < DB::Repo
  # Configure the repo
  self.record_class = Session

  # Document return types for reference
  returns_one :find, :find!, :first, :last, :find_by, :create, :update
  returns_many :all, :where, :many, :for_user

  # ===========================================================================
  # SINGLE RECORD METHODS
  # ===========================================================================

  # Create a new session for a user
  def create_for_user(user_id, ip_address: nil, user_agent: nil)
    record = Session.create!(
      user_id: user_id,
      ip_address: ip_address,
      user_agent: user_agent
    )
    to_struct(record)
  rescue ActiveRecord::RecordInvalid
    nil
  end

  # ===========================================================================
  # COLLECTION METHODS
  # ===========================================================================

  # Return all sessions for a user
  def for_user(user_id)
    base_scope
      .where(user_id: user_id)
      .map { |record| to_summary(record) }
  end

  # ===========================================================================
  # DELETION METHODS
  # ===========================================================================

  # Delete all sessions for a user (logout from all devices)
  def delete_all_for_user(user_id)
    Session.where(user_id: user_id).destroy_all
    true
  end

  # ===========================================================================
  # PROTECTED: Mapping methods
  # ===========================================================================

  protected

  # Default scope with ordering (most recent first)
  def base_scope
    Session.includes(:user).order(created_at: :desc)
  end

  # Build a full struct from a Session record
  def build_struct(record)
    SessionStruct.new(
      id: record.id,
      user_id: record.user_id,
      ip_address: record.ip_address,
      user_agent: record.user_agent,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  # Build a summary struct from a Session record
  def build_summary(record)
    SessionSummary.new(
      id: record.id,
      user_id: record.user_id,
      ip_address: record.ip_address,
      created_at: record.created_at
    )
  end

  # Full struct for single session
  SessionStruct = Data.define(:id, :user_id, :ip_address, :user_agent, :created_at, :updated_at)

  # Summary struct for session collections
  SessionSummary = Data.define(:id, :user_id, :ip_address, :created_at)
end