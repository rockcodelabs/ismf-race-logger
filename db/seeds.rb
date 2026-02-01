# frozen_string_literal: true

# ============================================================================
# ISMF RACE LOGGER - DATABASE SEEDS
# ============================================================================
#
# This file orchestrates seeding by loading modular seed files.
# Each seed file is idempotent and can be run multiple times.
#
# Seed files:
# - db/seeds/roles.rb - User roles
# - db/seeds/race_types.rb - Race type definitions
# - db/seeds/race_type_location_templates.rb - Location templates for race types
# - db/seeds/penalties.rb - ISMF penalty codes
# - db/seeds/users.rb - Users with PIN authentication
# - db/seeds/competitions_2026.rb - 2026 ISMF World Cup competitions
#
# To run specific sections, you can require individual files:
#   rails runner "load 'db/seeds/roles.rb'"
#   rails runner "load 'db/seeds/competitions_2026.rb'"
#
# ============================================================================

puts "=" * 80
puts "ISMF RACE LOGGER - SEEDING DATABASE"
puts "=" * 80

# Clear entire database before seeding
puts "\n▶ Clearing entire database..."
Report.delete_all
IncidentPenalty.delete_all
Incident.delete_all
RaceParticipation.delete_all
Team.delete_all
RaceLocation.delete_all
Race.delete_all
Competition.delete_all
Athlete.delete_all
RaceTypeLocationTemplate.delete_all
RaceType.delete_all
Session.delete_all
MagicLink.delete_all
User.delete_all
Role.delete_all
puts "✅ Database cleared"

# Load seed files in order
seed_files = [
  "roles",
  "race_types",
  "race_type_location_templates",
  "penalties",
  "users",
  "competitions_2026"
]

seed_files.each do |seed_file|
  seed_path = Rails.root.join("db", "seeds", "#{seed_file}.rb")
  
  if File.exist?(seed_path)
    puts "\n▶ Loading: db/seeds/#{seed_file}.rb"
    load seed_path
  else
    puts "\n⚠ Warning: Seed file not found: db/seeds/#{seed_file}.rb"
  end
end

puts "\n" + "=" * 80
puts "SEEDING COMPLETED!"
puts "=" * 80
puts ""
puts "Summary:"
puts "  Roles: #{Role.count}"
puts "  Race Types: #{RaceType.count}"
puts "  Location Templates: #{RaceTypeLocationTemplate.count}"
puts "  Penalties: #{Penalty.count}"
puts "  Users: #{User.count}"
puts "  Competitions: #{Competition.count}"
puts "  Athletes: #{Athlete.count}"
puts "  Races: #{Race.count}"
puts "  Race Locations: #{RaceLocation.count}"
puts "  Participations: #{RaceParticipation.count}"
puts "  Teams: #{Team.count}"
puts ""