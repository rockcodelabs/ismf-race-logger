# frozen_string_literal: true

class MagicLink < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :used, -> { where.not(used_at: nil) }

  def expired?
    expires_at < Time.current
  end

  def used?
    used_at.present?
  end

  def valid_for_use?
    !expired? && !used?
  end

  def consume!
    return false unless valid_for_use?

    update!(used_at: Time.current)
  end

  def self.find_and_consume(token)
    magic_link = valid.find_by(token: token)
    return nil unless magic_link

    magic_link.consume! ? magic_link : nil
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at ||= 15.minutes.from_now
  end
end