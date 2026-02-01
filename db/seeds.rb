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
# - db/seeds/location_templates.rb - Location templates for race types
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

# Load seed files in order
seed_files = [
  "roles",
  "race_types",
  "location_templates",
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
puts "  Users: #{User.count}"
puts "  Competitions: #{Competition.count}"
puts "  Athletes: #{Athlete.count}"
puts "  Races: #{Race.count}"
puts "  Participations: #{RaceParticipation.count}"
puts "  Teams: #{Team.count}"
puts ""