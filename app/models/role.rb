# frozen_string_literal: true

class Role < ApplicationRecord
  has_many :users, dependent: :nullify

  NAMES = %w[
    var_operator
    national_referee
    international_referee
    jury_president
    referee_manager
    broadcast_viewer
  ].freeze

  validates :name, presence: true, uniqueness: true, inclusion: { in: NAMES }

  scope :referee_roles, -> { where(name: %w[national_referee international_referee]) }
  scope :operator_roles, -> { where(name: "var_operator") }

  def referee?
    name.in?(%w[national_referee international_referee])
  end

  def operator?
    name == "var_operator"
  end

  def jury?
    name == "jury_president"
  end

  def manager?
    name == "referee_manager"
  end

  def viewer?
    name == "broadcast_viewer"
  end

  def self.seed_all!
    NAMES.each { |name| find_or_create_by!(name: name) }
  end
end