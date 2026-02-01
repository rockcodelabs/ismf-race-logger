# frozen_string_literal: true

# Report model (associations only)
#
# A report is a quick capture of a potential incident during a race.
# Created by referees/operators when they observe something noteworthy.
#
# Workflow:
# 1. Create report (location + bib) during live race
# 2. Review and confirm/reject
# 3. Merge confirmed reports into incidents
#
# Business logic lives in:
# - Operations: app/operations/reports/
# - Repo: app/db/repos/report_repo.rb
# - Struct: app/db/structs/report.rb
#
class Report < ApplicationRecord
  belongs_to :race
  belongs_to :incident, optional: true
  belongs_to :user
  belongs_to :race_location
  belongs_to :race_participation, optional: true

  # Video attachments (multiple videos per report)
  has_many_attached :videos

  # Generate client_uuid before validation if not present
  before_validation :ensure_client_uuid, on: :create

  private

  def ensure_client_uuid
    self.client_uuid ||= SecureRandom.uuid
  end
end
