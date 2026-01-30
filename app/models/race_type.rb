# frozen_string_literal: true

# RaceType model (associations only)
#
# Represents different types of ski mountaineering races:
# - individual
# - sprint
# - vertical
# - relay
#
# Each race_type has many races and defines location templates.
#
# Associations:
# - has_many :races
#
# Business logic lives in:
# - Types: lib/types.rb (RaceTypeName enum)
# - Repo: app/db/repos/race_type_repo.rb
# - Struct: app/db/structs/race_type.rb
#
class RaceType < ApplicationRecord
  has_many :races, dependent: :restrict_with_error
  has_many :location_templates, class_name: "RaceTypeLocationTemplate", dependent: :destroy
end