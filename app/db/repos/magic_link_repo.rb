# frozen_string_literal: true

# MagicLinkRepo - Repository for MagicLink data access (Hanami-style)
#
# This is the public interface for magic link persistence.
# All query logic lives here, NOT in the MagicLink model.
# Returns structs (immutable data objects), not ActiveRecord models.
#
# Example:
#   repo = MagicLinkRepo.new
#
#   link = repo.find_by_token("abc123")       # => MagicLinkStruct or nil
#   link = repo.create_for_user(user_id)      # => MagicLinkStruct or nil
#   repo.mark_as_used!(link.id)               # => MagicLinkStruct or nil
#
class MagicLinkRepo < DB::Repo
  # Configure the repo
  self.record_class = MagicLink

  # Default expiration time for new magic links
  DEFAULT_EXPIRATION = 24.hours

  # Document return types for reference
  returns_one :find, :find!, :first, :last, :find_by, :find_by_token, :create_for_user, :mark_as_used!
  returns_many :all, :where, :many, :for_user, :active_for_user, :expired

  # ===========================================================================
  # SINGLE RECORD METHODS
  # ===========================================================================

  # Find magic link by token
  def find_by_token(token)
    record = base_scope.find_by(token: token)
    to_struct(record)
  end

  # Find a valid (active, not expired, not used) magic link by token
  def find_valid_by_token(token)
    record = base_scope
      .where(token: token)
      .where("expires_at > ?", Time.current)
      .where(used_at: nil)
      .first
    to_struct(record)
  end

  # Create a new magic link for a user
  def create_for_user(user_id, expires_in: DEFAULT_EXPIRATION)
    record = MagicLink.create!(
      user_id: user_id,
      expires_at: Time.current + expires_in
    )
    to_struct(record)
  rescue ActiveRecord::RecordInvalid
    nil
  end

  # Mark a magic link as used
  def mark_as_used!(id)
    record = MagicLink.find(id)
    record.update!(used_at: Time.current)
    to_struct(record)
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    nil
  end

  # ===========================================================================
  # COLLECTION METHODS
  # ===========================================================================

  # Return all magic links for a user
  def for_user(user_id)
    base_scope
      .where(user_id: user_id)
      .map { |record| to_summary(record) }
  end

  # Return active (not expired, not used) magic links for a user
  def active_for_user(user_id)
    base_scope
      .where(user_id: user_id)
      .where("expires_at > ?", Time.current)
      .where(used_at: nil)
      .map { |record| to_summary(record) }
  end

  # Return all expired magic links
  def expired
    base_scope
      .where("expires_at <= ?", Time.current)
      .map { |record| to_summary(record) }
  end

  # Return all used magic links
  def used
    base_scope
      .where.not(used_at: nil)
      .map { |record| to_summary(record) }
  end

  # ===========================================================================
  # CLEANUP METHODS
  # ===========================================================================

  # Delete all expired magic links (cleanup job)
  def delete_expired!
    MagicLink.where("expires_at <= ?", Time.current).destroy_all
    true
  end

  # Delete all magic links for a user
  def delete_all_for_user(user_id)
    MagicLink.where(user_id: user_id).destroy_all
    true
  end

  # ===========================================================================
  # AGGREGATE METHODS
  # ===========================================================================

  # Check if user has any active magic links
  def has_active_link?(user_id)
    MagicLink
      .where(user_id: user_id)
      .where("expires_at > ?", Time.current)
      .where(used_at: nil)
      .exists?
  end

  # ===========================================================================
  # PROTECTED: Mapping methods
  # ===========================================================================

  protected

  # Default scope with eager loading and ordering
  def base_scope
    MagicLink.includes(:user).order(created_at: :desc)
  end

  # Build a full struct from a MagicLink record
  def build_struct(record)
    MagicLinkStruct.new(
      id: record.id,
      token: record.token,
      user_id: record.user_id,
      expires_at: record.expires_at,
      used_at: record.used_at,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  # Build a summary struct from a MagicLink record
  def build_summary(record)
    MagicLinkSummary.new(
      id: record.id,
      token: record.token,
      user_id: record.user_id,
      expires_at: record.expires_at,
      used_at: record.used_at,
      expired: record.expires_at <= Time.current,
      used: record.used_at.present?
    )
  end

  # Full struct for single magic link
  MagicLinkStruct = Data.define(
    :id, :token, :user_id, :expires_at, :used_at, :created_at, :updated_at
  ) do
    def expired?
      expires_at <= Time.current
    end

    def used?
      used_at.present?
    end

    def valid_for_use?
      !expired? && !used?
    end
  end

  # Summary struct for magic link collections
  MagicLinkSummary = Data.define(
    :id, :token, :user_id, :expires_at, :used_at, :expired, :used
  ) do
    def expired?
      expired
    end

    def used?
      used
    end

    def valid_for_use?
      !expired? && !used?
    end
  end
end
