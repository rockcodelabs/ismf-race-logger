class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  scope :admins, -> { where(admin: true) }

  def admin?
    admin == true
  end

  def display_name
    name.presence || email_address.split("@").first
  end
end