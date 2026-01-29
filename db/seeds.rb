# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create all roles first
puts "Creating roles..."
roles_data = [
  "var_operator",
  "national_referee",
  "international_referee",
  "jury_president",
  "referee_manager",
  "broadcast_viewer"
]

roles_data.each do |role_name|
  role = Role.find_or_create_by(name: role_name)
  puts "  ✓ #{role.name}"
end
puts "✅ Created #{Role.count} roles"

# Create race types
puts "Creating race types..."
race_types_data = [
  { name: "Individual", description: "Individual race format" },
  { name: "Team", description: "Team race format (2 athletes)" },
  { name: "Sprint", description: "Sprint race format with heats" },
  { name: "Vertical", description: "Vertical race format" },
  { name: "Mixed Relay", description: "Mixed relay race format" }
]

race_types_data.each do |race_type_data|
  race_type = RaceType.find_or_initialize_by(name: race_type_data[:name])
  race_type.assign_attributes(description: race_type_data[:description])
  if race_type.save
    puts "  ✓ #{race_type.name}"
  else
    puts "  ✗ Failed to create #{race_type_data[:name]}: #{race_type.errors.full_messages.join(', ')}"
  end
end
puts "✅ Created #{RaceType.count} race types"

# Get roles for assignment
referee_manager_role = Role.find_by(name: "referee_manager")
national_referee_role = Role.find_by(name: "national_referee")
var_operator_role = Role.find_by(name: "var_operator")

# Create admin user
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@ismf-ski.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "password123")
admin_name = ENV.fetch("ADMIN_NAME", "ISMF Admin")

admin = User.find_or_initialize_by(email_address: admin_email)
admin.assign_attributes(
  name: admin_name,
  password: admin_password,
  password_confirmation: admin_password,
  admin: true,
  role: referee_manager_role
)

if admin.save
  puts "✅ Admin user created/updated: #{admin.email_address} (role: #{admin.role&.name || 'none'})"
else
  puts "❌ Failed to create admin user: #{admin.errors.full_messages.join(', ')}"
end

# Create additional test users in development
if Rails.env.development?
  # Test user with no special role
  test_user = User.find_or_initialize_by(email_address: "user@example.com")
  test_user.assign_attributes(
    name: "Test User",
    password: "password123",
    password_confirmation: "password123",
    admin: false,
    role: nil
  )

  if test_user.save
    puts "✅ Test user created/updated: #{test_user.email_address}"
  else
    puts "❌ Failed to create test user: #{test_user.errors.full_messages.join(', ')}"
  end

  # National referee user
  referee_user = User.find_or_initialize_by(email_address: "referee@ismf-ski.com")
  referee_user.assign_attributes(
    name: "National Referee",
    password: "password123",
    password_confirmation: "password123",
    admin: false,
    role: national_referee_role
  )

  if referee_user.save
    puts "✅ Referee user created/updated: #{referee_user.email_address} (role: #{referee_user.role&.name})"
  else
    puts "❌ Failed to create referee user: #{referee_user.errors.full_messages.join(', ')}"
  end

  # VAR operator user
  var_user = User.find_or_initialize_by(email_address: "var@ismf-ski.com")
  var_user.assign_attributes(
    name: "VAR Operator",
    password: "password123",
    password_confirmation: "password123",
    admin: false,
    role: var_operator_role
  )

  if var_user.save
    puts "✅ VAR operator created/updated: #{var_user.email_address} (role: #{var_user.role&.name})"
  else
    puts "❌ Failed to create VAR operator: #{var_user.errors.full_messages.join(', ')}"
  end

  # Developer account
  dev_user = User.find_or_initialize_by(email_address: "dariusz.finster@gmail.com")
  dev_user.assign_attributes(
    name: "Dariusz Finster",
    password: "test",
    password_confirmation: "test",
    admin: true,
    role: var_operator_role
  )

  if dev_user.save
    puts "✅ Developer user created/updated: #{dev_user.email_address} (role: #{dev_user.role&.name})"
  else
    puts "❌ Failed to create developer user: #{dev_user.errors.full_messages.join(', ')}"
  end
end

puts ""
puts "=" * 80
puts "Creating World Cup Competition with Athletes and Races"
puts "=" * 80

# Create World Cup competition
puts "\nCreating World Cup competition..."
competition = Competition.find_or_initialize_by(
  name: "ISMF World Cup Font Blanca 2025"
)
# Use dynamic dates starting from now
base_time = 2.hours.from_now
start_date = base_time.to_date

competition.assign_attributes(
  description: "World Cup stage featuring Individual, Sprint, Vertical, and Mixed Relay races",
  start_date: start_date,
  end_date: start_date + 3.days,
  city: "Font Blanca",
  place: "Font Blanca Ski Resort",
  country: "AND",
  webpage_url: "https://www.ismf-ski.org/world-cup-2025"
)

if competition.save
  puts "✅ Competition created: #{competition.name}"
else
  puts "❌ Failed to create competition: #{competition.errors.full_messages.join(', ')}"
  exit
end

# Create 50 male and 50 female athletes from various countries
puts "\nCreating 100 athletes (50M / 50W)..."

# ISMF countries with strong ski mountaineering traditions
countries = %w[ITA FRA ESP CHE AUT USA CAN NOR SWE FIN DEU]

# Common first names
male_first_names = %w[
  Marco Luca Andrea Giovanni Michele Thomas Mathieu Pierre Jean Antoine
  Carlos David Alex Stefan Hans Peter Lars Erik Martin Anton
  Robert Simon Felix Max Paul Jonas Leon Noah Benjamin Samuel
  Daniel Michael Andreas Christian Matteo Francesco Lorenzo Gabriel
  Julian Sebastian Tobias Lukas Jakob Vincent Oscar Emil Filip
]

female_first_names = %w[
  Sofia Maria Laura Anna Giulia Emma Chiara Charlotte Amélie Claire
  Marie Sophie Léa Camille Elena Sara Marta Paula Carmen Isabel
  Anna Sophia Emma Mia Hannah Julia Laura Lisa Marie Nina
  Olivia Emily Sarah Anna Lena Maja Zoe Luna Alba Nora
  Valentina Francesca Beatrice Alessia Martina Elisa Giorgia Silvia
]

# Common last names by country
last_names = {
  "ITA" => %w[Rossi Bianchi Ferrari Romano Colombo Ricci Marino Greco Conti],
  "FRA" => %w[Bernard Dubois Martin Durand Petit Laurent Simon Michel Leroy],
  "ESP" => %w[Garcia Rodriguez Martinez Lopez Sanchez Perez Gonzalez Fernandez],
  "CHE" => %w[Müller Meier Schmidt Weber Fischer Schneider Keller Baumann],
  "AUT" => %w[Gruber Müller Wagner Huber Bauer Pichler Steiner Moser],
  "USA" => %w[Smith Johnson Williams Brown Jones Davis Miller Wilson Anderson],
  "CAN" => %w[MacDonald Campbell Stewart Robertson Murphy Fraser Henderson],
  "NOR" => %w[Hansen Johansen Olsen Larsen Andersen Pedersen Nilsen],
  "SWE" => %w[Andersson Johansson Karlsson Nilsson Eriksson Larsson],
  "FIN" => %w[Virtanen Mäkinen Nieminen Hämäläinen Laine Koskinen],
  "DEU" => %w[Müller Schmidt Schneider Fischer Weber Meyer Wagner]
}

athletes_created = { "M" => [], "W" => [] }

# Create 50 male athletes
50.times do |i|
  country = countries.sample
  first_name = male_first_names.sample
  last_name = last_names[country].sample
  
  athlete = Athlete.find_or_initialize_by(
    first_name: first_name,
    last_name: last_name,
    gender: "M",
    country: country
  )
  athlete.license_number = "M#{country}#{(1000 + i).to_s}" unless athlete.persisted?
  
  if athlete.save
    athletes_created["M"] << athlete
  else
    puts "  ⚠ Could not create athlete: #{first_name} #{last_name} (#{athlete.errors.full_messages.join(', ')})"
  end
end

# Create 50 female athletes
50.times do |i|
  country = countries.sample
  first_name = female_first_names.sample
  last_name = last_names[country].sample
  
  athlete = Athlete.find_or_initialize_by(
    first_name: first_name,
    last_name: last_name,
    gender: "F",
    country: country
  )
  athlete.license_number = "W#{country}#{(2000 + i).to_s}" unless athlete.persisted?
  
  if athlete.save
    athletes_created["W"] << athlete
  else
    puts "  ⚠ Could not create athlete: #{first_name} #{last_name} (#{athlete.errors.full_messages.join(', ')})"
  end
end

puts "✅ Created #{athletes_created['M'].count} male athletes"
puts "✅ Created #{athletes_created['W'].count} female athletes"

# Get race types
individual_type = RaceType.find_by(name: "Individual")
sprint_type = RaceType.find_by(name: "Sprint")
vertical_type = RaceType.find_by(name: "Vertical")
mixed_relay_type = RaceType.find_by(name: "Mixed Relay")

puts "\nCreating races for each discipline..."

# Helper to create race and participants with automatic position assignment
def create_race_with_participants(competition, race_type, stage_name, stage_type, gender_category, athletes, start_bib, scheduled_time)
  # Get next position for this competition
  max_position = Race.where(competition_id: competition.id).maximum(:position) || -1
  next_position = max_position + 1
  
  race = Race.find_or_initialize_by(
    competition: competition,
    race_type: race_type,
    stage_name: stage_name,
    stage_type: stage_type,
    gender_category: gender_category
  )
  
  race.assign_attributes(
    name: "#{race_type.name} #{stage_name} #{gender_category}",
    scheduled_at: scheduled_time,
    status: "scheduled",
    position: next_position
  )
  
  if race.save
    puts "  ✓ #{race.name} (#{athletes.count} participants)"
    
    # Add participants
    athletes.each_with_index do |athlete, index|
      participation = RaceParticipation.find_or_initialize_by(
        race: race,
        athlete: athlete
      )
      participation.assign_attributes(
        bib_number: start_bib + index,
        status: "registered"
      )
      participation.save
    end
    
    race
  else
    puts "  ✗ Failed to create race: #{race.errors.full_messages.join(', ')}"
    nil
  end
end

# Day 1 - INDIVIDUAL RACES (starting 2 hours from now)
day1_base = 2.hours.from_now

# 1. Individual Races (Men and Women) - Single race, no stages
puts "\n1. Individual Races (Day 1)"
individual_men_race = create_race_with_participants(
  competition,
  individual_type,
  "Final",
  "final",
  "M",
  athletes_created["M"],
  1,
  day1_base
)

individual_women_race = create_race_with_participants(
  competition,
  individual_type,
  "Final",
  "final",
  "W",
  athletes_created["W"],
  101,
  day1_base + 2.hours
)

# Day 2 - SPRINT RACES
day2_base = day1_base + 1.day

# 2. Sprint Races (Men and Women) - Full ISMF stages
# With 50 athletes: Qualification → 5 Heats → 2 Semifinals → Final
puts "\n2. Sprint Races (Day 2 - Senior Women, then Senior Men)"

# WOMEN SPRINT
puts "  Women Sprint:"

# Women Qualification - All 50 athletes
sprint_women_qual = create_race_with_participants(
  competition,
  sprint_type,
  "Qualification",
  "qualification",
  "W",
  athletes_created["W"],
  301,
  day2_base
)

# Women Heats - 5 heats x 6 athletes = 30 athletes (top 30 from qualification)
# Top 2 from each heat + 2 lucky losers = 12 advance to semifinals
5.times do |heat_num|
  heat_athletes = athletes_created["W"].slice(heat_num * 6, 6) || []
  next if heat_athletes.empty?
  
  heat_race = create_race_with_participants(
    competition,
    sprint_type,
    "Heat #{heat_num + 1}",
    "heat",
    "W",
    heat_athletes,
    320 + (heat_num * 10),
    day2_base + 2.hours + (heat_num * 10).minutes
  )
end

# Women Semifinals - 2 semifinals x 6 athletes = 12 athletes
# Top 2 from each + 2 lucky losers = 6 advance to final
2.times do |semi_num|
  semi_athletes = athletes_created["W"].slice(semi_num * 6, 6) || []
  next if semi_athletes.empty?
  
  semi_race = create_race_with_participants(
    competition,
    sprint_type,
    "Semifinal #{semi_num + 1}",
    "semifinal",
    "W",
    semi_athletes,
    370 + (semi_num * 10),
    day2_base + 4.hours + (semi_num * 15).minutes
  )
end

# Women Final - 6 athletes
sprint_women_final = create_race_with_participants(
  competition,
  sprint_type,
  "Final",
  "final",
  "W",
  athletes_created["W"].first(6),
  390,
  day2_base + 6.hours
)

# MEN SPRINT
puts "  Men Sprint:"

# Men Qualification - All 50 athletes
sprint_men_qual = create_race_with_participants(
  competition,
  sprint_type,
  "Qualification",
  "qualification",
  "M",
  athletes_created["M"],
  201,
  day2_base + 8.hours
)

# Men Heats - 5 heats x 6 athletes = 30 athletes
5.times do |heat_num|
  heat_athletes = athletes_created["M"].slice(heat_num * 6, 6) || []
  next if heat_athletes.empty?
  
  heat_race = create_race_with_participants(
    competition,
    sprint_type,
    "Heat #{heat_num + 1}",
    "heat",
    "M",
    heat_athletes,
    220 + (heat_num * 10),
    day2_base + 10.hours + (heat_num * 10).minutes
  )
end

# Men Semifinals - 2 semifinals x 6 athletes = 12 athletes
2.times do |semi_num|
  semi_athletes = athletes_created["M"].slice(semi_num * 6, 6) || []
  next if semi_athletes.empty?
  
  semi_race = create_race_with_participants(
    competition,
    sprint_type,
    "Semifinal #{semi_num + 1}",
    "semifinal",
    "M",
    semi_athletes,
    270 + (semi_num * 10),
    day2_base + 12.hours + (semi_num * 15).minutes
  )
end

# Men Final - 6 athletes
sprint_men_final = create_race_with_participants(
  competition,
  sprint_type,
  "Final",
  "final",
  "M",
  athletes_created["M"].first(6),
  290,
  day2_base + 14.hours
)

# Day 3 - VERTICAL RACES
day3_base = day1_base + 2.days

# 3. Vertical Races (Men and Women)
puts "\n3. Vertical Races (Day 3)"
vertical_men_race = create_race_with_participants(
  competition,
  vertical_type,
  "Final",
  "final",
  "M",
  athletes_created["M"],
  401,
  day3_base
)

vertical_women_race = create_race_with_participants(
  competition,
  vertical_type,
  "Final",
  "final",
  "W",
  athletes_created["W"],
  501,
  day3_base + 2.hours
)

# Day 4 - MIXED RELAY
day4_base = day1_base + 3.days

# 4. Mixed Relay - Full ISMF stages
# Qualification → Semifinals → Final
puts "\n4. Mixed Relay (Day 4)"

# Helper to create relay teams with participations
def create_relay_teams(race, male_athletes, female_athletes, start_bib, team_count)
  teams_created = 0
  team_count.times do |i|
    male_athlete = male_athletes[i]
    female_athlete = female_athletes[i]
    
    next unless male_athlete && female_athlete
    
    team = Team.find_or_initialize_by(
      race: race,
      athlete_1: male_athlete,
      athlete_2: female_athlete
    )
    
    team.assign_attributes(
      name: "#{male_athlete.country} Mixed #{i + 1}",
      team_type: "relay_team",
      bib_number: start_bib + i
    )
    
    if team.save
      # Create participations for both athletes with unique bib numbers
      # Athlete 1 gets team bib, Athlete 2 gets team bib + 5000
      participation1 = RaceParticipation.find_or_initialize_by(
        race: race,
        athlete: male_athlete
      )
      participation1.assign_attributes(
        team: team,
        bib_number: team.bib_number,
        status: "registered"
      )
      participation1.save
      
      participation2 = RaceParticipation.find_or_initialize_by(
        race: race,
        athlete: female_athlete
      )
      participation2.assign_attributes(
        team: team,
        bib_number: team.bib_number + 5000,
        status: "registered"
      )
      participation2.save
      teams_created += 1
    end
  end
  teams_created
end

# Qualification - 25 teams
max_position = Race.where(competition_id: competition.id).maximum(:position) || -1
next_position = max_position + 1

mixed_relay_qual = Race.find_or_initialize_by(
  competition: competition,
  race_type: mixed_relay_type,
  stage_name: "Qualification",
  stage_type: "qualification",
  gender_category: "MW"
)

mixed_relay_qual.assign_attributes(
  name: "Mixed Relay Qualification",
  scheduled_at: day4_base,
  status: "scheduled",
  position: next_position
)

if mixed_relay_qual.save
  puts "  ✓ Mixed Relay Qualification"
  teams = create_relay_teams(mixed_relay_qual, athletes_created["M"], athletes_created["W"], 601, 25)
  puts "    → Created #{teams} teams (#{teams * 2} participants)"
else
  puts "  ✗ Failed to create Mixed Relay Qualification: #{mixed_relay_qual.errors.full_messages.join(', ')}"
end

# Semifinals - 2 semifinals x 6 teams = 12 teams
# Top 3 from each semifinal = 6 teams advance to final
2.times do |semi_num|
  max_position = Race.where(competition_id: competition.id).maximum(:position) || -1
  next_position = max_position + 1
  
  mixed_relay_semi = Race.find_or_initialize_by(
    competition: competition,
    race_type: mixed_relay_type,
    stage_name: "Semifinal #{semi_num + 1}",
    stage_type: "semifinal",
    gender_category: "MW"
  )
  
  mixed_relay_semi.assign_attributes(
    name: "Mixed Relay Semifinal #{semi_num + 1}",
    scheduled_at: day4_base + 2.hours + (semi_num * 30).minutes,
    status: "scheduled",
    position: next_position
  )
  
  if mixed_relay_semi.save
    puts "  ✓ Mixed Relay Semifinal #{semi_num + 1}"
    # 6 teams per semifinal
    start_athlete = semi_num * 6
    teams = create_relay_teams(
      mixed_relay_semi,
      athletes_created["M"].slice(start_athlete, 6) || [],
      athletes_created["W"].slice(start_athlete, 6) || [],
      640 + (semi_num * 10),
      6
    )
    puts "    → Created #{teams} teams (#{teams * 2} participants)"
  end
end

# Final - 6 teams
max_position = Race.where(competition_id: competition.id).maximum(:position) || -1
next_position = max_position + 1

mixed_relay_final = Race.find_or_initialize_by(
  competition: competition,
  race_type: mixed_relay_type,
  stage_name: "Final",
  stage_type: "final",
  gender_category: "MW"
)

mixed_relay_final.assign_attributes(
  name: "Mixed Relay Final",
  scheduled_at: day4_base + 4.hours,
  status: "scheduled",
  position: next_position
)

if mixed_relay_final.save
  puts "  ✓ Mixed Relay Final"
  teams = create_relay_teams(mixed_relay_final, athletes_created["M"], athletes_created["W"], 670, 6)
  puts "    → Created #{teams} teams (#{teams * 2} participants)"
else
  puts "  ✗ Failed to create Mixed Relay Final: #{mixed_relay_final.errors.full_messages.join(', ')}"
end

puts ""
puts "=" * 80
puts "Seeding completed!"
puts "=" * 80
puts "  Total roles: #{Role.count}"
puts "  Total race types: #{RaceType.count}"
puts "  Total users: #{User.count}"
puts "  Admin users: #{User.where(admin: true).count}"
puts "  Referees: #{User.joins(:role).where(roles: { name: ['national_referee', 'international_referee'] }).count}"
puts "  VAR operators: #{User.joins(:role).where(roles: { name: 'var_operator' }).count}"
puts ""
puts "  Competitions: #{Competition.count}"
puts "  Athletes: #{Athlete.count} (#{Athlete.where(gender: 'M').count}M / #{Athlete.where(gender: 'F').count}W)"
puts "  Races: #{Race.count}"
puts "  Race Participations: #{RaceParticipation.count}"
puts "  Teams: #{Team.count}"
puts ""
puts "World Cup: #{competition.name}"
puts "  Location: #{competition.city}, #{competition.country}"
puts "  Dates: #{competition.start_date} - #{competition.end_date}"
puts "  Schedule:"
puts ""
puts "    Day 1 (#{start_date.strftime('%b %d')}) - Individual Races:"
puts "      - Individual M Final (#{individual_men_race.race_participations.count} participants)" if individual_men_race
puts "      - Individual W Final (#{individual_women_race.race_participations.count} participants)" if individual_women_race
puts ""
puts "    Day 2 (#{(start_date + 1.day).strftime('%b %d')}) - Sprint Races (Full stages: Qual → Heats → Semis → Final):"
puts "      - Sprint W: #{Race.where(competition: competition, race_type: sprint_type, gender_category: 'W').count} stages"
puts "      - Sprint M: #{Race.where(competition: competition, race_type: sprint_type, gender_category: 'M').count} stages"
puts ""
puts "    Day 3 (#{(start_date + 2.days).strftime('%b %d')}) - Vertical Races:"
puts "      - Vertical M Final (#{vertical_men_race.race_participations.count} participants)" if vertical_men_race
puts "      - Vertical W Final (#{vertical_women_race.race_participations.count} participants)" if vertical_women_race
puts ""
puts "    Day 4 (#{(start_date + 3.days).strftime('%b %d')}) - Mixed Relay (Full stages: Qual → Semis → Final):"
puts "      - #{Race.where(competition: competition, race_type: mixed_relay_type).count} stages"
puts "      - Total teams: #{Team.where(race: Race.where(competition: competition, race_type: mixed_relay_type)).count}"
puts ""