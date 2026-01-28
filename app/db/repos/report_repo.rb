# frozen_string_literal: true

# ReportRepo - Repository for Report data access (Hanami-style)
#
# This is the public interface for report persistence.
# All query logic lives here, NOT in the Report model.
# Returns structs (immutable data objects), not ActiveRecord models.
#
# TODO: Implement fully when Report model is migrated
#
# Example:
#   repo = ReportRepo.new
#
#   report = repo.find(1)              # => Structs::Report or nil
#   reports = repo.all                 # => [Structs::ReportSummary, ...]
#   reports = repo.for_race(race_id)   # => [Structs::ReportSummary, ...]
#
class ReportRepo < DB::Repo
  # TODO: Configure when Report model exists
  # self.record_class = Report
  # self.struct_class = Structs::Report
  # self.summary_class = Structs::ReportSummary

  # Document return types for reference
  returns_one :find, :find!, :first, :last, :find_by, :create, :update
  returns_many :all, :where, :many, :for_race, :for_user, :pending, :submitted

  # ===========================================================================
  # PLACEHOLDER METHODS
  # These will be implemented when Report model is migrated
  # ===========================================================================

  def find(_id)
    raise NotImplementedError, "ReportRepo#find not yet implemented"
  end

  def all
    raise NotImplementedError, "ReportRepo#all not yet implemented"
  end

  def for_race(_race_id)
    raise NotImplementedError, "ReportRepo#for_race not yet implemented"
  end

  def for_user(_user_id)
    raise NotImplementedError, "ReportRepo#for_user not yet implemented"
  end

  protected

  def build_struct(_record)
    raise NotImplementedError, "ReportRepo#build_struct not yet implemented"
  end

  def build_summary(_record)
    raise NotImplementedError, "ReportRepo#build_summary not yet implemented"
  end
end