# frozen_string_literal: true

# ============================================================================
# 2026 ISMF WORLD CUP COMPETITIONS
# ============================================================================

puts ""
puts "=" * 80
puts "Creating 2026 ISMF World Cup Competitions"
puts "=" * 80

# Clear existing data
puts "\nClearing existing competition data..."
Report.delete_all
IncidentPenalty.delete_all
Incident.delete_all
RaceParticipation.delete_all
Team.delete_all
RaceLocation.delete_all
Race.delete_all
Competition.delete_all
Athlete.delete_all
puts "✅ Cleared existing data"

# Get race types
individual_type = RaceType.find_by(name: "Individual")
sprint_type = RaceType.find_by(name: "Sprint")
vertical_type = RaceType.find_by(name: "Vertical")
mixed_relay_type = RaceType.find_by(name: "Mixed Relay")

# ============================================================================
# ATHLETES
# ============================================================================

puts "\nCreating athletes..."

# ISMF countries with strong ski mountaineering traditions
countries = %w[ITA FRA ESP CHE AUT USA CAN NOR SWE FIN DEU AND]

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
  "DEU" => %w[Müller Schmidt Schneider Fischer Weber Meyer Wagner],
  "AND" => %w[Pujol Vila Serra Roca Font Torres Navarro]
}

athletes = { "M" => [], "W" => [] }

# Create 60 male athletes
60.times do |i|
  country = countries.sample
  first_name = male_first_names.sample
  last_name = last_names[country].sample
  
  athlete = Athlete.create!(
    first_name: first_name,
    last_name: last_name,
    gender: "M",
    country: country,
    license_number: "2026M#{i.to_s.rjust(4, '0')}"
  )
  athletes["M"] << athlete
end

# Create 60 female athletes
60.times do |i|
  country = countries.sample
  first_name = female_first_names.sample
  last_name = last_names[country].sample
  
  athlete = Athlete.create!(
    first_name: first_name,
    last_name: last_name,
    gender: "W",
    country: country,
    license_number: "2026W#{i.to_s.rjust(4, '0')}"
  )
  athletes["W"] << athlete
end

puts "✅ Created #{athletes['M'].count} male athletes"
puts "✅ Created #{athletes['W'].count} female athletes"

# ============================================================================
# HELPER METHODS
# ============================================================================

def create_race_with_participants(competition, race_type, stage_name, stage_type, gender_category, athletes, start_bib, scheduled_time)
  # Get next position for this competition
  max_position = Race.where(competition_id: competition.id).maximum(:position) || -1
  next_position = max_position + 1
  
  race = Race.create!(
    competition: competition,
    race_type: race_type,
    stage_name: stage_name,
    stage_type: stage_type,
    gender_category: gender_category,
    name: "#{race_type.name} #{stage_name} #{gender_category}",
    scheduled_at: scheduled_time,
    status: "scheduled",
    position: next_position
  )
  
  # Add participants
  athletes.each_with_index do |athlete, index|
    RaceParticipation.create!(
      race: race,
      athlete: athlete,
      bib_number: start_bib + index,
      status: "registered"
    )
  end
  
  race
end

def create_relay_race_with_teams(competition, race_type, stage_name, stage_type, male_athletes, female_athletes, start_bib, scheduled_time, team_count)
  max_position = Race.where(competition_id: competition.id).maximum(:position) || -1
  next_position = max_position + 1
  
  race = Race.create!(
    competition: competition,
    race_type: race_type,
    stage_name: stage_name,
    stage_type: stage_type,
    gender_category: "MW",
    name: "Mixed Relay #{stage_name}",
    scheduled_at: scheduled_time,
    status: "scheduled",
    position: next_position
  )
  
  # Create teams
  team_count.times do |i|
    male_athlete = male_athletes[i]
    female_athlete = female_athletes[i]
    
    next unless male_athlete && female_athlete
    
    team = Team.create!(
      race: race,
      athlete_1: male_athlete,
      athlete_2: female_athlete,
      name: "#{male_athlete.country} Mixed #{i + 1}",
      team_type: "relay_team",
      bib_number: start_bib + i
    )
    
    # Create participations for both athletes
    RaceParticipation.create!(
      race: race,
      athlete: male_athlete,
      team: team,
      bib_number: team.bib_number,
      status: "registered"
    )
    
    RaceParticipation.create!(
      race: race,
      athlete: female_athlete,
      team: team,
      bib_number: team.bib_number + 5000,
      status: "registered"
    )
  end
  
  race
end

# ============================================================================
# COMPETITION 1: VAL THORENS - SPRINT RACES
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 1: Val Thorens Sprint - January 25, 2026"
puts "=" * 80

val_thorens = Competition.create!(
  name: "ISMF World Cup Val Thorens 2026",
  description: "Sprint race",
  start_date: Date.new(2026, 1, 25),
  end_date: Date.new(2026, 1, 25),
  city: "Val Thorens",
  place: "Val Thorens Ski Resort",
  country: "FRA",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

base_time = val_thorens.start_date.to_time + 10.hours

# Women Sprint Final (30 athletes)
create_race_with_participants(
  val_thorens, sprint_type, "Final", "final", "W",
  athletes["W"].first(30), 101, base_time
)

# Men Sprint Final (30 athletes)
create_race_with_participants(
  val_thorens, sprint_type, "Final", "final", "M",
  athletes["M"].first(30), 201, base_time + 2.hours
)

puts "✅ Created Val Thorens Sprint races"

# ============================================================================
# COMPETITION 2: FLAINE - MIXED RELAY
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 2: Flaine Mixed Relay - January 26, 2026"
puts "=" * 80

flaine = Competition.create!(
  name: "ISMF World Cup Flaine 2026",
  description: "Mixed Relay race",
  start_date: Date.new(2026, 1, 26),
  end_date: Date.new(2026, 1, 26),
  city: "Flaine",
  place: "Flaine Ski Resort",
  country: "FRA",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

base_time = flaine.start_date.to_time + 11.hours

# Mixed Relay Final (20 teams)
create_relay_race_with_teams(
  flaine, mixed_relay_type, "Final", "final",
  athletes["M"], athletes["W"], 301, base_time, 20
)

puts "✅ Created Flaine Mixed Relay race"

# ============================================================================
# COMPETITION 3: KRANJSKA GORA - VERTICAL RACE
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 3: Kranjska Gora Vertical - February 21, 2026"
puts "=" * 80

kranjska = Competition.create!(
  name: "ISMF World Cup Kranjska Gora 2026",
  description: "Vertical race",
  start_date: Date.new(2026, 2, 21),
  end_date: Date.new(2026, 2, 21),
  city: "Kranjska Gora",
  place: "Kranjska Gora Ski Resort",
  country: "AND",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

base_time = kranjska.start_date.to_time + 10.hours

# Women Vertical Final
create_race_with_participants(
  kranjska, vertical_type, "Final", "final", "W",
  athletes["W"].first(40), 501, base_time
)

# Men Vertical Final
create_race_with_participants(
  kranjska, vertical_type, "Final", "final", "M",
  athletes["M"].first(40), 601, base_time + 2.hours
)

puts "✅ Created Kranjska Gora Vertical races"

# ============================================================================
# COMPETITION 4: WORLD CUP SPRINT - FEBRUARY 22, 2026
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 4: World Cup Sprint - February 22, 2026"
puts "=" * 80

wc_sprint_feb = Competition.create!(
  name: "ISMF World Cup Sprint February 2026",
  description: "Sprint race",
  start_date: Date.new(2026, 2, 22),
  end_date: Date.new(2026, 2, 22),
  city: "TBD",
  place: "TBD",
  country: "TBD",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

base_time = wc_sprint_feb.start_date.to_time + 10.hours

# Women Sprint Final
create_race_with_participants(
  wc_sprint_feb, sprint_type, "Final", "final", "W",
  athletes["W"].first(30), 101, base_time
)

# Men Sprint Final
create_race_with_participants(
  wc_sprint_feb, sprint_type, "Final", "final", "M",
  athletes["M"].first(30), 201, base_time + 2.hours
)

puts "✅ Created World Cup Sprint (Feb 22) races"

# ============================================================================
# COMPETITION 5: WORLD CUP SPRINT - MARCH 8, 2026
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 5: World Cup Sprint - March 8, 2026"
puts "=" * 80

wc_sprint_mar = Competition.create!(
  name: "ISMF World Cup Sprint March 2026",
  description: "Sprint race",
  start_date: Date.new(2026, 3, 8),
  end_date: Date.new(2026, 3, 8),
  city: "TBD",
  place: "TBD",
  country: "TBD",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

base_time = wc_sprint_mar.start_date.to_time + 10.hours

# Women Sprint Final
create_race_with_participants(
  wc_sprint_mar, sprint_type, "Final", "final", "W",
  athletes["W"].first(30), 101, base_time
)

# Men Sprint Final
create_race_with_participants(
  wc_sprint_mar, sprint_type, "Final", "final", "M",
  athletes["M"].first(30), 201, base_time + 2.hours
)

puts "✅ Created World Cup Sprint (Mar 8) races"

# ============================================================================
# COMPETITION 6: WORLD CUP MIXED RELAY - MARCH 9, 2026
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 6: World Cup Mixed Relay - March 9, 2026"
puts "=" * 80

wc_relay_mar = Competition.create!(
  name: "ISMF World Cup Mixed Relay March 2026",
  description: "Mixed Relay race",
  start_date: Date.new(2026, 3, 9),
  end_date: Date.new(2026, 3, 9),
  city: "TBD",
  place: "TBD",
  country: "TBD",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

base_time = wc_relay_mar.start_date.to_time + 11.hours

# Mixed Relay Final
create_relay_race_with_teams(
  wc_relay_mar, mixed_relay_type, "Final", "final",
  athletes["M"], athletes["W"], 301, base_time, 20
)

puts "✅ Created World Cup Mixed Relay (Mar 9) race"

# ============================================================================
# SUMMARY
# ============================================================================

puts ""
puts "=" * 80
puts "2026 World Cup Competitions Summary"
puts "=" * 80
puts "  Total Competitions: #{Competition.count}"
puts "  Total Athletes: #{Athlete.count} (#{athletes['M'].count}M / #{athletes['W'].count}W)"
puts "  Total Races: #{Race.count}"
puts "  Total Participations: #{RaceParticipation.count}"
puts "  Total Teams: #{Team.count}"
puts ""

Competition.order(:start_date).each do |comp|
  puts "#{comp.start_date.strftime('%b %d, %Y')}: #{comp.name}"
  puts "  Location: #{comp.city}, #{comp.country}"
  puts "  Races: #{comp.races.count}"
  puts ""
end