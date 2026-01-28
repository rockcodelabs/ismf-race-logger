# frozen_string_literal: true

# IncidentRepo - Repository for Incident data access (Hanami-style)
#
# This is the public interface for incident persistence.
# All query logic lives here, NOT in the Incident model.
# Returns structs (immutable data objects), not ActiveRecord models.
#
# TODO: Implement fully when Incident model is migrated
#
# Example:
#   repo = IncidentRepo.new
#
#   incident = repo.find(1)                    # => Structs::Incident or nil
#   incidents = repo.for_race(race_id)         # => [Structs::IncidentSummary, ...]
#   incidents = repo.pending                   # => [Structs::IncidentSummary, ...]
#
class IncidentRepo < DB::Repo
  # Configure the repo (uncomment when Incident model exists)
  # self.record_class = Incident
  # self.struct_class = Structs::Incident
  # self.summary_class = Structs::IncidentSummary

  # Document return types for reference
  returns_one :find, :find!, :first, :last, :find_by, :create, :update
  returns_many :all, :where, :many, :for_race, :pending, :official, :unofficial

  # ===========================================================================
  # PLACEHOLDER METHODS
  # TODO: Implement when Incident model is migrated
  # ===========================================================================

  def find(id)
    raise NotImplementedError, "IncidentRepo#find not yet implemented"
  end

  def all
    raise NotImplementedError, "IncidentRepo#all not yet implemented"
  end

  def for_race(race_id)
    raise NotImplementedError, "IncidentRepo#for_race not yet implemented"
  end

  def pending
    raise NotImplementedError, "IncidentRepo#pending not yet implemented"
  end

  def official
    raise NotImplementedError, "IncidentRepo#official not yet implemented"
  end

  def unofficial
    raise NotImplementedError, "IncidentRepo#unofficial not yet implemented"
  end

  protected

  def build_struct(record)
    raise NotImplementedError, "IncidentRepo#build_struct not yet implemented"
  end

  def build_summary(record)
    raise NotImplementedError, "IncidentRepo#build_summary not yet implemented"
  end
end