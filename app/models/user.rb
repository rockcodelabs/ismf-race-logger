# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  belongs_to :role, optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  scope :admins, -> { where(admin: true) }
  scope :referees, -> { joins(:role).where(roles: { name: %w[national_referee international_referee] }) }
  scope :var_operators, -> { joins(:role).where(roles: { name: "var_operator" }) }
  scope :with_role, ->(role_name) { joins(:role).where(roles: { name: role_name }) }

  def admin?
    admin == true
  end

  def display_name
    name.presence || email_address.split("@").first
  end

  def generate_magic_link!
    magic_links.create!
  end

  # Role check methods
  def var_operator?
    role&.name == "var_operator"
  end

  def national_referee?
    role&.name == "national_referee"
  end

  def international_referee?
    role&.name == "international_referee"
  end

  def jury_president?
    role&.name == "jury_president"
  end

  def referee_manager?
    role&.name == "referee_manager"
  end

  def broadcast_viewer?
    role&.name == "broadcast_viewer"
  end

  def referee?
    national_referee? || international_referee?
  end

  def has_role?(role_name)
    role&.name == role_name.to_s
  end
end