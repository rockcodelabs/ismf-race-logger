# frozen_string_literal: true

# Policy for Note authorization
#
# v1: Any authenticated user can manage notes.
# Notes are collaborative — any user can add notes to reports/incidents.
#
class NotePolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def update?
    user.present?
  end

  def destroy?
    user.present?
  end
end