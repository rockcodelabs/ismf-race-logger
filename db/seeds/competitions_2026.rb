# frozen_string_literal: true

# ============================================================================
# 2026 ISMF WORLD CUP COMPETITIONS
# ============================================================================

puts ""
puts "=" * 80
puts "Creating 2026 ISMF World Cup Competitions"
puts "=" * 80

# Clear competition-specific data (main seed.rb clears everything first)
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
puts "✅ Cleared existing competition data"

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

athletes = { "M" => [], "F" => [] }

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
    gender: "F",
    country: country,
    license_number: "2026F#{i.to_s.rjust(4, '0')}"
  )
  athletes["F"] << athlete
end

puts "✅ Created #{athletes['M'].count} male athletes"
puts "✅ Created #{athletes['F'].count} female athletes"

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
# DYNAMIC DATE CALCULATION
# ============================================================================

# Base time: now (closest race starts immediately)
base_datetime = Time.now

# ============================================================================
# COMPETITION 1: VAL THORENS - SPRINT RACES
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 1: Val Thorens Sprint - #{base_datetime.strftime('%B %d, %Y')}"
puts "=" * 80

comp1_start = base_datetime.to_date
comp1_end = comp1_start

val_thorens = Competition.create!(
  name: "ISMF World Cup Val Thorens 2026",
  description: "Sprint race with full competition format",
  start_date: comp1_start,
  end_date: comp1_end,
  city: "Val Thorens",
  place: "Val Thorens Ski Resort",
  country: "FRA",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

race_time = base_datetime

# SPRINT WOMEN - Full competition format
# Qualifications (all 60 women)
create_race_with_participants(
  val_thorens, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"], 1, race_time
)

# Heats (top 30 from qualifications, 5 heats of 6)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 1", "heat", "W",
  athletes["F"][0..5], 1, race_time + 30.minutes
)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 2", "heat", "W",
  athletes["F"][6..11], 7, race_time + 35.minutes
)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 3", "heat", "W",
  athletes["F"][12..17], 13, race_time + 40.minutes
)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 4", "heat", "W",
  athletes["F"][18..23], 19, race_time + 45.minutes
)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 5", "heat", "W",
  athletes["F"][24..29], 25, race_time + 50.minutes
)

# Semi-finals (top 12, 2 semis of 6)
create_race_with_participants(
  val_thorens, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][0..5], 1, race_time + 1.hour
)
create_race_with_participants(
  val_thorens, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][6..11], 7, race_time + 1.hour + 5.minutes
)

# Final (top 6)
create_race_with_participants(
  val_thorens, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time + 1.hour + 15.minutes
)

# SPRINT MEN - Full competition format
# Qualifications (all 60 men)
create_race_with_participants(
  val_thorens, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"], 101, race_time + 2.hours
)

# Heats (top 30 from qualifications, 5 heats of 6)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 1", "heat", "M",
  athletes["M"][0..5], 101, race_time + 2.hours + 30.minutes
)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 2", "heat", "M",
  athletes["M"][6..11], 107, race_time + 2.hours + 35.minutes
)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 3", "heat", "M",
  athletes["M"][12..17], 113, race_time + 2.hours + 40.minutes
)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 4", "heat", "M",
  athletes["M"][18..23], 119, race_time + 2.hours + 45.minutes
)
create_race_with_participants(
  val_thorens, sprint_type, "Heat 5", "heat", "M",
  athletes["M"][24..29], 125, race_time + 2.hours + 50.minutes
)

# Semi-finals (top 12, 2 semis of 6)
create_race_with_participants(
  val_thorens, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][0..5], 101, race_time + 3.hours
)
create_race_with_participants(
  val_thorens, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][6..11], 107, race_time + 3.hours + 5.minutes
)

# Final (top 6)
create_race_with_participants(
  val_thorens, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time + 3.hours + 15.minutes
)

# Individual races
create_race_with_participants(
  val_thorens, individual_type, "Final", "final", "W",
  athletes["F"][10..49], 201, race_time + 4.hours
)

create_race_with_participants(
  val_thorens, individual_type, "Final", "final", "M",
  athletes["M"][10..49], 301, race_time + 6.hours
)

# Mixed Relay
# MIXED RELAY - Full competition format
# Qualifications (20 teams)
create_relay_race_with_teams(
  val_thorens, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][30..49], athletes["F"][30..49], 501, race_time + 8.hours, 20
)

# Semi-finals (top 12 teams, 2 semis of 6)
create_relay_race_with_teams(
  val_thorens, mixed_relay_type, "Semi-Final 1", "semi_final",
  athletes["M"][30..35], athletes["F"][30..35], 501, race_time + 8.hours + 30.minutes, 6
)
create_relay_race_with_teams(
  val_thorens, mixed_relay_type, "Semi-Final 2", "semi_final",
  athletes["M"][36..41], athletes["F"][36..41], 507, race_time + 8.hours + 35.minutes, 6
)

# Final (top 6 teams)
create_relay_race_with_teams(
  val_thorens, mixed_relay_type, "Final", "final",
  athletes["M"][30..35], athletes["F"][30..35], 501, race_time + 9.hours, 6
)

puts "✅ Created Val Thorens races (Sprint, Individual, Mixed Relay)"

# ============================================================================
# COMPETITION 2: FLAINE - MIXED RELAY
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 2: Flaine Mixed Relay - #{(base_datetime + 1.day).strftime('%B %d, %Y')}"
puts "=" * 80

comp2_start = (base_datetime + 1.day).to_date
comp2_end = comp2_start

flaine = Competition.create!(
  name: "ISMF World Cup Flaine 2026",
  description: "Mixed Relay race with full competition format",
  start_date: comp2_start,
  end_date: comp2_end,
  city: "Flaine",
  place: "Flaine Ski Resort",
  country: "FRA",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

race_time = base_datetime + 1.day

# SPRINT WOMEN - Full competition format
create_race_with_participants(
  flaine, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"], 1, race_time
)
5.times do |i|
  create_race_with_participants(
    flaine, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    flaine, sprint_type, "Semi-Final #{i + 1}", "semi_final", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 1.hour + (i * 5).minutes
  )
end
create_race_with_participants(
  flaine, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time + 1.hour + 15.minutes
)

# SPRINT MEN - Full competition format
create_race_with_participants(
  flaine, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"], 101, race_time + 2.hours
)
5.times do |i|
  create_race_with_participants(
    flaine, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 2.hours + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    flaine, sprint_type, "Semi-Final #{i + 1}", "semi_final", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 3.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  flaine, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time + 3.hours + 15.minutes
)

# Vertical races
create_race_with_participants(
  flaine, vertical_type, "Final", "final", "W",
  athletes["F"][15..54], 201, race_time + 4.hours
)

create_race_with_participants(
  flaine, vertical_type, "Final", "final", "M",
  athletes["M"][15..54], 301, race_time + 6.hours
)

# MIXED RELAY - Full competition format
create_relay_race_with_teams(
  flaine, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][25..44], athletes["F"][25..44], 501, race_time + 8.hours, 20
)
2.times do |i|
  create_relay_race_with_teams(
    flaine, mixed_relay_type, "Semi-Final #{i + 1}", "semi_final",
    athletes["M"][(25 + i * 6)..(25 + i * 6 + 5)], athletes["F"][(25 + i * 6)..(25 + i * 6 + 5)], 
    501 + i * 6, race_time + 8.hours + 30.minutes + (i * 5).minutes, 6
  )
end
create_relay_race_with_teams(
  flaine, mixed_relay_type, "Final", "final",
  athletes["M"][25..30], athletes["F"][25..30], 501, race_time + 9.hours, 6
)

puts "✅ Created Flaine races (Sprint, Vertical, Mixed Relay)"

# ============================================================================
# COMPETITION 3: KRANJSKA GORA - VERTICAL RACE
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 3: Kranjska Gora Vertical - #{(base_datetime + 2.days).strftime('%B %d, %Y')}"
puts "=" * 80

comp3_start = (base_datetime + 2.days).to_date
comp3_end = comp3_start

kranjska = Competition.create!(
  name: "ISMF World Cup Kranjska Gora 2026",
  description: "Vertical race with full competition format",
  start_date: comp3_start,
  end_date: comp3_end,
  city: "Kranjska Gora",
  place: "Kranjska Gora Ski Resort",
  country: "AND",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

race_time = base_datetime + 2.days

# SPRINT WOMEN - Full competition format
create_race_with_participants(
  kranjska, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"], 1, race_time
)
5.times do |i|
  create_race_with_participants(
    kranjska, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    kranjska, sprint_type, "Semi-Final #{i + 1}", "semi_final", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 1.hour + (i * 5).minutes
  )
end
create_race_with_participants(
  kranjska, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time + 1.hour + 15.minutes
)

# SPRINT MEN - Full competition format
create_race_with_participants(
  kranjska, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"], 101, race_time + 2.hours
)
5.times do |i|
  create_race_with_participants(
    kranjska, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 2.hours + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    kranjska, sprint_type, "Semi-Final #{i + 1}", "semi_final", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 3.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  kranjska, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time + 3.hours + 15.minutes
)

# Women Vertical Final
create_race_with_participants(
  kranjska, vertical_type, "Final", "final", "W",
  athletes["F"].first(40), 501, race_time + 4.hours
)

# Men Vertical Final
create_race_with_participants(
  kranjska, vertical_type, "Final", "final", "M",
  athletes["M"].first(40), 601, race_time + 6.hours
)

# Individual races
create_race_with_participants(
  kranjska, individual_type, "Final", "final", "W",
  athletes["F"][5..44], 701, race_time + 8.hours
)

create_race_with_participants(
  kranjska, individual_type, "Final", "final", "M",
  athletes["M"][5..44], 801, race_time + 10.hours
)

# MIXED RELAY - Full competition format
create_relay_race_with_teams(
  kranjska, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][30..49], athletes["F"][30..49], 901, race_time + 12.hours, 20
)
2.times do |i|
  create_relay_race_with_teams(
    kranjska, mixed_relay_type, "Semi-Final #{i + 1}", "semi_final",
    athletes["M"][(30 + i * 6)..(30 + i * 6 + 5)], athletes["F"][(30 + i * 6)..(30 + i * 6 + 5)], 
    901 + i * 6, race_time + 12.hours + 30.minutes + (i * 5).minutes, 6
  )
end
create_relay_race_with_teams(
  kranjska, mixed_relay_type, "Final", "final",
  athletes["M"][30..35], athletes["F"][30..35], 901, race_time + 13.hours, 6
)

puts "✅ Created Kranjska Gora races (Sprint, Vertical, Individual, Mixed Relay)"

# ============================================================================
# COMPETITION 4: WORLD CUP SPRINT - DAY 3
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 4: World Cup Sprint - #{(base_datetime + 3.days).strftime('%B %d, %Y')}"
puts "=" * 80

comp4_start = (base_datetime + 3.days).to_date
comp4_end = comp4_start

wc_sprint_feb = Competition.create!(
  name: "ISMF World Cup Sprint February 2026",
  description: "Sprint race with full competition format",
  start_date: comp4_start,
  end_date: comp4_end,
  city: "TBD",
  place: "TBD",
  country: "TBD",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

race_time = base_datetime + 3.days

# SPRINT WOMEN - Full competition format
create_race_with_participants(
  wc_sprint_feb, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"], 1, race_time
)
5.times do |i|
  create_race_with_participants(
    wc_sprint_feb, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    wc_sprint_feb, sprint_type, "Semi-Final #{i + 1}", "semi_final", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 1.hour + (i * 5).minutes
  )
end
create_race_with_participants(
  wc_sprint_feb, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time + 1.hour + 15.minutes
)

# SPRINT MEN - Full competition format
create_race_with_participants(
  wc_sprint_feb, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"], 101, race_time + 2.hours
)
5.times do |i|
  create_race_with_participants(
    wc_sprint_feb, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 2.hours + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    wc_sprint_feb, sprint_type, "Semi-Final #{i + 1}", "semi_final", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 3.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  wc_sprint_feb, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time + 3.hours + 15.minutes
)

# Vertical races
create_race_with_participants(
  wc_sprint_feb, vertical_type, "Final", "final", "W",
  athletes["F"][20..59], 201, race_time + 4.hours
)

create_race_with_participants(
  wc_sprint_feb, vertical_type, "Final", "final", "M",
  athletes["M"][20..59], 301, race_time + 6.hours
)

# MIXED RELAY - Full competition format
create_relay_race_with_teams(
  wc_sprint_feb, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][35..54], athletes["F"][35..54], 501, race_time + 8.hours, 20
)
2.times do |i|
  create_relay_race_with_teams(
    wc_sprint_feb, mixed_relay_type, "Semi-Final #{i + 1}", "semi_final",
    athletes["M"][(35 + i * 6)..(35 + i * 6 + 5)], athletes["F"][(35 + i * 6)..(35 + i * 6 + 5)], 
    501 + i * 6, race_time + 8.hours + 30.minutes + (i * 5).minutes, 6
  )
end
create_relay_race_with_teams(
  wc_sprint_feb, mixed_relay_type, "Final", "final",
  athletes["M"][35..40], athletes["F"][35..40], 501, race_time + 9.hours, 6
)

puts "✅ Created World Cup races (Sprint, Vertical, Mixed Relay)"

# ============================================================================
# COMPETITION 5: WORLD CUP SPRINT - DAY 4
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 5: World Cup Sprint - #{(base_datetime + 4.days).strftime('%B %d, %Y')}"
puts "=" * 80

comp5_start = (base_datetime + 4.days).to_date
comp5_end = comp5_start

wc_sprint_mar = Competition.create!(
  name: "ISMF World Cup Sprint March 2026",
  description: "Sprint race with full competition format",
  start_date: comp5_start,
  end_date: comp5_end,
  city: "TBD",
  place: "TBD",
  country: "TBD",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

race_time = base_datetime + 4.days

# SPRINT WOMEN - Full competition format
create_race_with_participants(
  wc_sprint_mar, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"], 1, race_time
)
5.times do |i|
  create_race_with_participants(
    wc_sprint_mar, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    wc_sprint_mar, sprint_type, "Semi-Final #{i + 1}", "semi_final", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 1.hour + (i * 5).minutes
  )
end
create_race_with_participants(
  wc_sprint_mar, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time + 1.hour + 15.minutes
)

# SPRINT MEN - Full competition format
create_race_with_participants(
  wc_sprint_mar, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"], 101, race_time + 2.hours
)
5.times do |i|
  create_race_with_participants(
    wc_sprint_mar, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 2.hours + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    wc_sprint_mar, sprint_type, "Semi-Final #{i + 1}", "semi_final", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 3.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  wc_sprint_mar, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time + 3.hours + 15.minutes
)

# Individual races
create_race_with_participants(
  wc_sprint_mar, individual_type, "Final", "final", "W",
  athletes["F"][10..49], 201, race_time + 4.hours
)

create_race_with_participants(
  wc_sprint_mar, individual_type, "Final", "final", "M",
  athletes["M"][10..49], 301, race_time + 6.hours
)

# Vertical races
create_race_with_participants(
  wc_sprint_mar, vertical_type, "Final", "final", "W",
  athletes["F"][25..59], 401, race_time + 8.hours
)

create_race_with_participants(
  wc_sprint_mar, vertical_type, "Final", "final", "M",
  athletes["M"][25..59], 501, race_time + 10.hours
)

# MIXED RELAY - Full competition format
create_relay_race_with_teams(
  wc_sprint_mar, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][40..59], athletes["F"][40..59], 601, race_time + 12.hours, 20
)
2.times do |i|
  create_relay_race_with_teams(
    wc_sprint_mar, mixed_relay_type, "Semi-Final #{i + 1}", "semi_final",
    athletes["M"][(40 + i * 6)..(40 + i * 6 + 5)], athletes["F"][(40 + i * 6)..(40 + i * 6 + 5)], 
    601 + i * 6, race_time + 12.hours + 30.minutes + (i * 5).minutes, 6
  )
end
create_relay_race_with_teams(
  wc_sprint_mar, mixed_relay_type, "Final", "final",
  athletes["M"][40..45], athletes["F"][40..45], 601, race_time + 13.hours, 6
)

puts "✅ Created World Cup races (Sprint, Individual, Vertical, Mixed Relay)"

# ============================================================================
# COMPETITION 6: WORLD CUP MIXED RELAY - DAY 5
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 6: World Cup Mixed Relay - #{(base_datetime + 5.days).strftime('%B %d, %Y')}"
puts "=" * 80

comp6_start = (base_datetime + 5.days).to_date
comp6_end = comp6_start

wc_relay_mar = Competition.create!(
  name: "ISMF World Cup Mixed Relay March 2026",
  description: "Mixed Relay race with full competition format",
  start_date: comp6_start,
  end_date: comp6_end,
  city: "TBD",
  place: "TBD",
  country: "TBD",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

race_time = base_datetime + 5.days

# SPRINT WOMEN - Full competition format
create_race_with_participants(
  wc_relay_mar, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"], 1, race_time
)
5.times do |i|
  create_race_with_participants(
    wc_relay_mar, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    wc_relay_mar, sprint_type, "Semi-Final #{i + 1}", "semi_final", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time + 1.hour + (i * 5).minutes
  )
end
create_race_with_participants(
  wc_relay_mar, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time + 1.hour + 15.minutes
)

# SPRINT MEN - Full competition format
create_race_with_participants(
  wc_relay_mar, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"], 101, race_time + 2.hours
)
5.times do |i|
  create_race_with_participants(
    wc_relay_mar, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 2.hours + 30.minutes + (i * 5).minutes
  )
end
2.times do |i|
  create_race_with_participants(
    wc_relay_mar, sprint_type, "Semi-Final #{i + 1}", "semi_final", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time + 3.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  wc_relay_mar, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time + 3.hours + 15.minutes
)

# Individual races
create_race_with_participants(
  wc_relay_mar, individual_type, "Final", "final", "W",
  athletes["F"][5..44], 201, race_time + 4.hours
)

create_race_with_participants(
  wc_relay_mar, individual_type, "Final", "final", "M",
  athletes["M"][5..44], 301, race_time + 6.hours
)

# MIXED RELAY - Full competition format
create_relay_race_with_teams(
  wc_relay_mar, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][45..59] + athletes["M"][0..4], athletes["F"][45..59] + athletes["F"][0..4], 
  501, race_time + 8.hours, 20
)
2.times do |i|
  create_relay_race_with_teams(
    wc_relay_mar, mixed_relay_type, "Semi-Final #{i + 1}", "semi_final",
    athletes["M"][(45 + i * 6)..(45 + i * 6 + 5)], athletes["F"][(45 + i * 6)..(45 + i * 6 + 5)], 
    501 + i * 6, race_time + 8.hours + 30.minutes + (i * 5).minutes, 6
  )
end
create_relay_race_with_teams(
  wc_relay_mar, mixed_relay_type, "Final", "final",
  athletes["M"][45..50], athletes["F"][45..50], 501, race_time + 9.hours, 6
)

puts "✅ Created World Cup races (Sprint, Individual, Mixed Relay)"

# ============================================================================
# SUMMARY
# ============================================================================

puts ""
puts "=" * 80
puts "2026 World Cup Competitions Summary"
puts "=" * 80
puts "  Total Competitions: #{Competition.count}"
puts "  Total Athletes: #{Athlete.count} (#{athletes['M'].count}M / #{athletes['F'].count}F)"
puts "  Total Races: #{Race.count}"
puts "  Total Participations: #{RaceParticipation.count}"
puts "  Total Teams: #{Team.count}"
puts ""

Competition.order(:start_date).each do |comp|
  puts "#{comp.start_date.strftime('%b %d, %Y')}: #{comp.name}"
  puts "  Location: #{comp.city}, #{comp.country}"
  puts "  Races: #{comp.races.count}"
  comp.races.order(:position).each do |race|
    puts "    #{race.position + 1}. #{race.name} at #{race.scheduled_at.strftime('%H:%M')}"
  end
  puts ""
end