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
team_type = RaceType.find_by(name: "Team")

# ============================================================================
# ATHLETES
# ============================================================================

puts "\nCreating athletes..."

# ISMF countries with strong ski mountaineering traditions
countries = %w[ITA FRA ESP CHE AUT USA CAN NOR SWE FIN DEU AND AZE CHN KOR]

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
  "AND" => %w[Pujol Vila Serra Roca Font Torres Navarro],
  "AZE" => %w[Aliyev Mammadov Huseynov Ismayilov Hasanov Rahimov],
  "CHN" => %w[Wang Li Zhang Liu Chen Yang Huang Zhao Wu Zhou],
  "KOR" => %w[Kim Lee Park Choi Jung Kang Cho Yoon Jang Lim]
}

athletes = { "M" => [], "F" => [] }

# Create 80 male athletes
80.times do |i|
  country = countries.sample
  first_name = male_first_names.sample
  last_name = last_names[country]&.sample || "Smith"
  
  athlete = Athlete.create!(
    first_name: first_name,
    last_name: last_name,
    gender: "M",
    country: country,
    license_number: "2026M#{i.to_s.rjust(4, '0')}"
  )
  athletes["M"] << athlete
end

# Create 80 female athletes
80.times do |i|
  country = countries.sample
  first_name = female_first_names.sample
  last_name = last_names[country]&.sample || "Johnson"
  
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

def create_race_with_participants(competition, race_type, stage_name, stage_type, gender_category, athletes, start_bib, scheduled_time, status = "scheduled", skip_participants: false)
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
    status: status,
    position: next_position
  )
  
  unless skip_participants
    athletes.each_with_index do |athlete, index|
      bib = start_bib + index
      bib = ((bib - 1) % 200) + 1 if bib > 200  # Keep bibs between 1-200
      RaceParticipation.create!(
        race: race,
        athlete: athlete,
        bib_number: bib,
        status: "registered"
      )
    end
  end
  
  # Populate race locations from templates
  Operations::Races::PopulateLocations.new.call(race_id: race.id, race_type_id: race_type.id)
  
  race
end

def create_relay_race_with_teams(competition, race_type, stage_name, stage_type, male_athletes, female_athletes, start_bib, scheduled_time, team_count, status = "scheduled", skip_participants: false)
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
    status: status,
    position: next_position
  )
  
  unless skip_participants
    team_count.times do |i|
      male_athlete = male_athletes[i]
      female_athlete = female_athletes[i]
      
      next unless male_athlete && female_athlete
      
      team_bib = start_bib + i
      team_bib = ((team_bib - 1) % 200) + 1 if team_bib > 200  # Keep bibs between 1-200
      
      team = Team.create!(
        race: race,
        athlete_1: male_athlete,
        athlete_2: female_athlete,
        name: "#{male_athlete.country} Mixed #{i + 1}",
        team_type: "relay_team",
        bib_number: team_bib
      )
      
      # Each athlete gets unique bib for relay teams - male uses team bib, female adds 50
      male_bib = team_bib
      female_bib = team_bib + 50
      female_bib = ((female_bib - 1) % 200) + 1 if female_bib > 200
      
      RaceParticipation.create!(
        race: race,
        athlete: male_athlete,
        team: team,
        bib_number: male_bib,
        status: "registered"
      )
      
      RaceParticipation.create!(
        race: race,
        athlete: female_athlete,
        team: team,
        bib_number: female_bib,
        status: "registered"
      )
    end
  end
  
  # Populate race locations from templates
  Operations::Races::PopulateLocations.new.call(race_id: race.id, race_type_id: race_type.id)
  
  race
end

def create_team_race(competition, race_type, stage_name, stage_type, gender_category, athletes, start_bib, scheduled_time, team_size = 2, status = "scheduled", skip_participants: false)
  max_position = Race.where(competition_id: competition.id).maximum(:position) || -1
  next_position = max_position + 1
  
  race = Race.create!(
    competition: competition,
    race_type: race_type,
    stage_name: stage_name,
    stage_type: stage_type,
    gender_category: gender_category,
    name: "Team #{stage_name} #{gender_category}",
    scheduled_at: scheduled_time,
    status: status,
    position: next_position
  )
  
  # Create teams
  unless skip_participants
    team_count = [athletes.count / team_size, 15].min
    team_count.times do |i|
      team_athletes = athletes[(i * team_size)...(i * team_size + team_size)]
      next if team_athletes.count < team_size
      
      team_bib = start_bib + i
      team_bib = ((team_bib - 1) % 200) + 1 if team_bib > 200  # Keep bibs between 1-200
      
      team = Team.create!(
        race: race,
        athlete_1: team_athletes[0],
        athlete_2: team_athletes[1],
        name: "#{team_athletes[0].country} Team #{i + 1}",
        team_type: "race_team",
        bib_number: team_bib
      )
      
      # Each team member gets unique bib - use larger offset to avoid collisions
      team_athletes.each_with_index do |athlete, idx|
        athlete_bib = team_bib + (idx * 50)
        athlete_bib = ((athlete_bib - 1) % 200) + 1 if athlete_bib > 200
        
        RaceParticipation.create!(
          race: race,
          athlete: athlete,
          team: team,
          bib_number: athlete_bib,
          status: "registered"
        )
      end
    end
  end
  
  # Populate race locations from templates
  Operations::Races::PopulateLocations.new.call(race_id: race.id, race_type_id: race_type.id)
  
  race
end

# ============================================================================
# DYNAMIC DATE CALCULATION
# ============================================================================

# Base time: now (Boí Taüll sprint semi-finals are ongoing)
base_datetime = Time.now

# ============================================================================
# COMPETITION 1: BOÍ TAÜLL - MIXED RELAY & SPRINT (ONGOING)
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 1: Boí Taüll World Cup - #{base_datetime.strftime('%B %d, %Y')}"
puts "=" * 80

boi_taull_start = (base_datetime - 1.day).to_date
boi_taull_end = base_datetime.to_date

boi_taull = Competition.create!(
  name: "ISMF Boí Taüll World Cup",
  description: "Mixed Relay and Sprint races",
  start_date: boi_taull_start,
  end_date: boi_taull_end,
  city: "Boí Taüll",
  place: "Boí Taüll Ski Resort",
  country: "ESP",
  webpage_url: "https://www.ismf-ski.org/world-cup-2026"
)

race_time = base_datetime

# Mixed Relay (yesterday - all completed)
create_relay_race_with_teams(
  boi_taull, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][0..19], athletes["F"][0..19], 1, race_time - 1.day + 10.hours, 20, "completed"
)
create_relay_race_with_teams(
  boi_taull, mixed_relay_type, "Semi-Final 1", "semi_final",
  athletes["M"][0..5], athletes["F"][0..5], 1, race_time - 1.day + 11.hours, 6, "completed", skip_participants: true
)
create_relay_race_with_teams(
  boi_taull, mixed_relay_type, "Semi-Final 2", "semi_final",
  athletes["M"][6..11], athletes["F"][6..11], 7, race_time - 1.day + 11.hours + 5.minutes, 6, "completed", skip_participants: true
)
create_relay_race_with_teams(
  boi_taull, mixed_relay_type, "Final", "final",
  athletes["M"][0..5], athletes["F"][0..5], 1, race_time - 1.day + 12.hours, 6, "completed", skip_participants: true
)

# Sprint Women (today - semi-finals ongoing)
create_race_with_participants(
  boi_taull, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][20..79], 1, race_time - 30.minutes, "completed"
)
5.times do |i|
  create_race_with_participants(
    boi_taull, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][20 + (i * 6)..20 + (i * 6) + 5], 1 + i * 6, race_time - 20.minutes + (i * 2).minutes, "completed", skip_participants: true
  )
end
create_race_with_participants(
  boi_taull, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][20..25], 1, race_time - 3.minutes, "in_progress"
)
create_race_with_participants(
  boi_taull, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][26..31], 7, race_time + 2.minutes, "scheduled", skip_participants: true
)
create_race_with_participants(
  boi_taull, sprint_type, "Final", "final", "W",
  athletes["F"][20..25], 1, race_time + 30.minutes, skip_participants: true
)

# Sprint Men (today - upcoming)
create_race_with_participants(
  boi_taull, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][20..79], 101, race_time + 1.hour
)
5.times do |i|
  create_race_with_participants(
    boi_taull, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][20 + (i * 6)..20 + (i * 6) + 5], 101 + i * 6, race_time + 1.5.hours + (i * 2).minutes, "scheduled", skip_participants: true
  )
end
create_race_with_participants(
  boi_taull, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][20..25], 101, race_time + 2.hours, "scheduled", skip_participants: true
)
create_race_with_participants(
  boi_taull, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][26..31], 107, race_time + 2.hours + 5.minutes, "scheduled", skip_participants: true
)
create_race_with_participants(
  boi_taull, sprint_type, "Final", "final", "M",
  athletes["M"][20..25], 101, race_time + 2.5.hours, "scheduled", skip_participants: true
)

puts "✅ Created Boí Taüll races (Mixed Relay, Sprint)"

# ============================================================================
# COMPETITION 2: ALTITOY - TEAM RACE
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 2: Altitoy Series - #{base_datetime.strftime('%B %d, %Y')}"
puts "=" * 80

altitoy = Competition.create!(
  name: "ISMF Series 1 – France / Altitoy",
  description: "Team race competition",
  start_date: boi_taull_start,
  end_date: boi_taull_end,
  city: "Luz-Saint-Sauveur",
  place: "Luz-Saint-Sauveur",
  country: "FRA",
  webpage_url: "https://www.ismf-ski.org"
)

# Team races (today - upcoming)
create_team_race(
  altitoy, team_type, "Final", "final", "MM",
  athletes["M"][32..61], 101, race_time + 3.hours, 2
)
create_team_race(
  altitoy, team_type, "Final", "final", "WW",
  athletes["F"][32..61], 151, race_time + 5.hours, 2
)

puts "✅ Created Altitoy races (Team)"

# ============================================================================
# COMPETITION 3: BERCHTESGADEN YOUTH WORLD CUP
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 3: Berchtesgaden Youth World Cup - #{(base_datetime + 4.days).strftime('%B %d, %Y')}"
puts "=" * 80

berchtesgaden_start = (base_datetime + 4.days).to_date
berchtesgaden_end = (base_datetime + 7.days).to_date

berchtesgaden = Competition.create!(
  name: "ISMF Berchtesgaden Youth World Cup",
  description: "Youth competition with Sprint, Vertical, and Individual races",
  start_date: berchtesgaden_start,
  end_date: berchtesgaden_end,
  city: "Berchtesgaden",
  place: "Berchtesgaden",
  country: "DEU",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_berch = base_datetime + 4.days + 10.hours

# Sprint races
create_race_with_participants(
  berchtesgaden, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][0..29], 1, race_time_berch
)
5.times do |i|
  create_race_with_participants(
    berchtesgaden, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time_berch + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  berchtesgaden, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][0..5], 1, race_time_berch + 1.hour
)
create_race_with_participants(
  berchtesgaden, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][6..11], 7, race_time_berch + 1.hour + 5.minutes
)
create_race_with_participants(
  berchtesgaden, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time_berch + 1.hour + 15.minutes
)

create_race_with_participants(
  berchtesgaden, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][0..29], 101, race_time_berch + 2.hours
)
5.times do |i|
  create_race_with_participants(
    berchtesgaden, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time_berch + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  berchtesgaden, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][0..5], 101, race_time_berch + 3.hours
)
create_race_with_participants(
  berchtesgaden, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][6..11], 107, race_time_berch + 3.hours + 5.minutes
)
create_race_with_participants(
  berchtesgaden, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time_berch + 3.hours + 15.minutes
)

# Vertical races (next day)
race_time_berch_v = race_time_berch + 1.day
create_race_with_participants(
  berchtesgaden, vertical_type, "Final", "final", "W",
  athletes["F"][10..49], 201, race_time_berch_v
)
create_race_with_participants(
  berchtesgaden, vertical_type, "Final", "final", "M",
  athletes["M"][10..49], 301, race_time_berch_v + 2.hours
)

# Individual races (day 3)
race_time_berch_i = race_time_berch + 2.days
create_race_with_participants(
  berchtesgaden, individual_type, "Final", "final", "W",
  athletes["F"][15..54], 401, race_time_berch_i
)
create_race_with_participants(
  berchtesgaden, individual_type, "Final", "final", "M",
  athletes["M"][15..54], 501, race_time_berch_i + 2.hours
)

puts "✅ Created Berchtesgaden races (Sprint, Vertical, Individual)"

# ============================================================================
# COMPETITION 4: OLYMPIC WINTER GAMES MILANO CORTINA 2026
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 4: Olympic Winter Games Milano Cortina 2026 - #{(base_datetime + 5.days).strftime('%B %d, %Y')}"
puts "=" * 80

olympics_start = (base_datetime + 5.days).to_date
olympics_end = (base_datetime + 21.days).to_date

olympics = Competition.create!(
  name: "Olympic Winter Games Milano Cortina 2026",
  description: "Olympic ski mountaineering competition",
  start_date: olympics_start,
  end_date: olympics_end,
  city: "Bormio",
  place: "Bormio",
  country: "ITA",
  webpage_url: "https://www.olympics.com"
)

race_time_oly = base_datetime + 7.days + 10.hours

# Sprint races
create_race_with_participants(
  olympics, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][0..39], 1, race_time_oly
)
5.times do |i|
  create_race_with_participants(
    olympics, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time_oly + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  olympics, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][0..5], 1, race_time_oly + 1.hour
)
create_race_with_participants(
  olympics, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][6..11], 7, race_time_oly + 1.hour + 5.minutes
)
create_race_with_participants(
  olympics, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time_oly + 1.hour + 15.minutes
)

create_race_with_participants(
  olympics, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][0..39], 101, race_time_oly + 2.hours
)
5.times do |i|
  create_race_with_participants(
    olympics, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time_oly + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  olympics, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][0..5], 101, race_time_oly + 3.hours
)
create_race_with_participants(
  olympics, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][6..11], 107, race_time_oly + 3.hours + 5.minutes
)
create_race_with_participants(
  olympics, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time_oly + 3.hours + 15.minutes
)

# Mixed Relay (different day)
race_time_oly_relay = race_time_oly + 3.days
create_relay_race_with_teams(
  olympics, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][20..39], athletes["F"][20..39], 201, race_time_oly_relay, 20
)
create_relay_race_with_teams(
  olympics, mixed_relay_type, "Semi-Final 1", "semi_final",
  athletes["M"][20..25], athletes["F"][20..25], 201, race_time_oly_relay + 1.hour, 6
)
create_relay_race_with_teams(
  olympics, mixed_relay_type, "Semi-Final 2", "semi_final",
  athletes["M"][26..31], athletes["F"][26..31], 207, race_time_oly_relay + 1.hour + 5.minutes, 6
)
create_relay_race_with_teams(
  olympics, mixed_relay_type, "Final", "final",
  athletes["M"][20..25], athletes["F"][20..25], 201, race_time_oly_relay + 2.hours, 6
)

puts "✅ Created Olympic Games races (Mixed Relay, Sprint)"

# ============================================================================
# COMPETITION 5: SURNADAL YOUTH WORLD CUP
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 5: Surnadal Youth World Cup - #{(base_datetime + 11.days).strftime('%B %d, %Y')}"
puts "=" * 80

surnadal_start = (base_datetime + 11.days).to_date
surnadal_end = (base_datetime + 14.days).to_date

surnadal = Competition.create!(
  name: "ISMF Surnadal Youth World Cup",
  description: "Youth competition with Sprint, Vertical, and Individual races",
  start_date: surnadal_start,
  end_date: surnadal_end,
  city: "Surnadal",
  place: "Surnadal",
  country: "NOR",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_sur = base_datetime + 11.days + 10.hours

# Sprint races
create_race_with_participants(
  surnadal, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][30..59], 1, race_time_sur
)
5.times do |i|
  create_race_with_participants(
    surnadal, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][30 + (i * 6)..30 + (i * 6) + 5], i * 6 + 1, race_time_sur + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  surnadal, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][30..35], 1, race_time_sur + 1.hour
)
create_race_with_participants(
  surnadal, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][36..41], 7, race_time_sur + 1.hour + 5.minutes
)
create_race_with_participants(
  surnadal, sprint_type, "Final", "final", "W",
  athletes["F"][30..35], 1, race_time_sur + 1.hour + 15.minutes
)

create_race_with_participants(
  surnadal, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][30..59], 101, race_time_sur + 2.hours
)
5.times do |i|
  create_race_with_participants(
    surnadal, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][30 + (i * 6)..30 + (i * 6) + 5], 101 + i * 6, race_time_sur + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  surnadal, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][30..35], 101, race_time_sur + 3.hours
)
create_race_with_participants(
  surnadal, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][36..41], 107, race_time_sur + 3.hours + 5.minutes
)
create_race_with_participants(
  surnadal, sprint_type, "Final", "final", "M",
  athletes["M"][30..35], 101, race_time_sur + 3.hours + 15.minutes
)

# Vertical & Individual races
race_time_sur_v = race_time_sur + 1.day
create_race_with_participants(
  surnadal, vertical_type, "Final", "final", "W",
  athletes["F"][35..64], 201, race_time_sur_v
)
create_race_with_participants(
  surnadal, vertical_type, "Final", "final", "M",
  athletes["M"][35..64], 301, race_time_sur_v + 2.hours
)

race_time_sur_i = race_time_sur + 2.days
create_race_with_participants(
  surnadal, individual_type, "Final", "final", "W",
  athletes["F"][40..69], 401, race_time_sur_i
)
create_race_with_participants(
  surnadal, individual_type, "Final", "final", "M",
  athletes["M"][40..69], 501, race_time_sur_i + 2.hours
)

puts "✅ Created Surnadal races (Sprint, Vertical, Individual)"

# ============================================================================
# COMPETITION 6: TRANSCAVALLO SERIES
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 6: Transcavallo Series - #{(base_datetime + 26.days).strftime('%B %d, %Y')}"
puts "=" * 80

transcavallo_start = (base_datetime + 26.days).to_date
transcavallo_end = (base_datetime + 28.days).to_date

transcavallo = Competition.create!(
  name: "ISMF Series 2 – Italy / Transcavallo",
  description: "Team and Individual races",
  start_date: transcavallo_start,
  end_date: transcavallo_end,
  city: "Friuli Venezia Giulia",
  place: "Friuli Venezia Giulia",
  country: "ITA",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_tc = base_datetime + 26.days + 10.hours

create_race_with_participants(
  transcavallo, individual_type, "Final", "final", "W",
  athletes["F"][0..39], 1, race_time_tc
)
create_race_with_participants(
  transcavallo, individual_type, "Final", "final", "M",
  athletes["M"][0..39], 101, race_time_tc + 2.hours
)
create_team_race(
  transcavallo, team_type, "Final", "final", "MM",
  athletes["M"][40..69], 201, race_time_tc + 4.hours, 2
)
create_team_race(
  transcavallo, team_type, "Final", "final", "WW",
  athletes["F"][40..69], 301, race_time_tc + 6.hours, 2
)

puts "✅ Created Transcavallo races (Individual, Team)"

# ============================================================================
# COMPETITION 7: EUROPEAN CHAMPIONSHIPS SHAHDAG
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 7: European Championships Shahdag - #{(base_datetime + 31.days).strftime('%B %d, %Y')}"
puts "=" * 80

euro_start = (base_datetime + 31.days).to_date
euro_end = (base_datetime + 35.days).to_date

euro = Competition.create!(
  name: "ISMF European Championships",
  description: "Major championship with all race types",
  start_date: euro_start,
  end_date: euro_end,
  city: "Shahdag",
  place: "Shahdag Mountain Resort",
  country: "AZE",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_euro = base_datetime + 31.days + 10.hours

# Sprint races (Day 1)
create_race_with_participants(
  euro, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][0..49], 1, race_time_euro
)
5.times do |i|
  create_race_with_participants(
    euro, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time_euro + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  euro, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][0..5], 1, race_time_euro + 1.hour
)
create_race_with_participants(
  euro, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][6..11], 7, race_time_euro + 1.hour + 5.minutes
)
create_race_with_participants(
  euro, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time_euro + 1.hour + 15.minutes
)

create_race_with_participants(
  euro, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][0..49], 101, race_time_euro + 2.hours
)
5.times do |i|
  create_race_with_participants(
    euro, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time_euro + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  euro, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][0..5], 101, race_time_euro + 3.hours
)
create_race_with_participants(
  euro, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][6..11], 107, race_time_euro + 3.hours + 5.minutes
)
create_race_with_participants(
  euro, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time_euro + 3.hours + 15.minutes
)

# Vertical races (Day 2)
race_time_euro_v = race_time_euro + 1.day
create_race_with_participants(
  euro, vertical_type, "Final", "final", "W",
  athletes["F"][10..59], 201, race_time_euro_v
)
create_race_with_participants(
  euro, vertical_type, "Final", "final", "M",
  athletes["M"][10..59], 301, race_time_euro_v + 2.hours
)

# Individual races (Day 3)
race_time_euro_i = race_time_euro + 2.days
create_race_with_participants(
  euro, individual_type, "Final", "final", "W",
  athletes["F"][15..64], 401, race_time_euro_i
)
create_race_with_participants(
  euro, individual_type, "Final", "final", "M",
  athletes["M"][15..64], 501, race_time_euro_i + 2.hours
)

# Mixed Relay (Day 4)
race_time_euro_mr = race_time_euro + 3.days
create_relay_race_with_teams(
  euro, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][20..39], athletes["F"][20..39], 601, race_time_euro_mr, 20
)
create_relay_race_with_teams(
  euro, mixed_relay_type, "Semi-Final 1", "semi_final",
  athletes["M"][20..25], athletes["F"][20..25], 601, race_time_euro_mr + 1.hour, 6
)
create_relay_race_with_teams(
  euro, mixed_relay_type, "Semi-Final 2", "semi_final",
  athletes["M"][26..31], athletes["F"][26..31], 607, race_time_euro_mr + 1.hour + 5.minutes, 6
)
create_relay_race_with_teams(
  euro, mixed_relay_type, "Final", "final",
  athletes["M"][20..25], athletes["F"][20..25], 601, race_time_euro_mr + 2.hours, 6
)

puts "✅ Created European Championships races (Mixed Relay, Sprint, Vertical, Individual)"

# ============================================================================
# COMPETITION 8: SHAHDAG WORLD CUP
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 8: Shahdag World Cup - #{(base_datetime + 33.days).strftime('%B %d, %Y')}"
puts "=" * 80

shahdag_start = (base_datetime + 33.days).to_date
shahdag_end = (base_datetime + 35.days).to_date

shahdag = Competition.create!(
  name: "ISMF Shahdag World Cup",
  description: "Vertical and Individual races",
  start_date: shahdag_start,
  end_date: shahdag_end,
  city: "Shahdag",
  place: "Shahdag Mountain Resort",
  country: "AZE",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_shah = base_datetime + 33.days + 10.hours

create_race_with_participants(
  shahdag, vertical_type, "Final", "final", "W",
  athletes["F"][20..59], 1, race_time_shah
)
create_race_with_participants(
  shahdag, vertical_type, "Final", "final", "M",
  athletes["M"][20..59], 101, race_time_shah + 2.hours
)

race_time_shah_i = race_time_shah + 1.day
create_race_with_participants(
  shahdag, individual_type, "Final", "final", "W",
  athletes["F"][25..64], 201, race_time_shah_i
)
create_race_with_participants(
  shahdag, individual_type, "Final", "final", "M",
  athletes["M"][25..64], 301, race_time_shah_i + 2.hours
)

puts "✅ Created Shahdag World Cup races (Vertical, Individual)"

# ============================================================================
# COMPETITION 9: SOUTH KOREA SERIES
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 9: South Korea Series - #{(base_datetime + 34.days).strftime('%B %d, %Y')}"
puts "=" * 80

korea_start = (base_datetime + 34.days).to_date
korea_end = (base_datetime + 35.days).to_date

korea = Competition.create!(
  name: "ISMF Series 3 – South Korea",
  description: "Sprint and Vertical races",
  start_date: korea_start,
  end_date: korea_end,
  city: "Gangwon State",
  place: "Gangwon State",
  country: "KOR",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_kor = base_datetime + 34.days + 10.hours

# Sprint races
create_race_with_participants(
  korea, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][30..59], 1, race_time_kor
)
5.times do |i|
  create_race_with_participants(
    korea, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][30 + (i * 6)..30 + (i * 6) + 5], i * 6 + 1, race_time_kor + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  korea, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][30..35], 1, race_time_kor + 1.hour
)
create_race_with_participants(
  korea, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][36..41], 7, race_time_kor + 1.hour + 5.minutes
)
create_race_with_participants(
  korea, sprint_type, "Final", "final", "W",
  athletes["F"][30..35], 1, race_time_kor + 1.hour + 15.minutes
)

create_race_with_participants(
  korea, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][30..59], 101, race_time_kor + 2.hours
)
5.times do |i|
  create_race_with_participants(
    korea, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][30 + (i * 6)..30 + (i * 6) + 5], 101 + i * 6, race_time_kor + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  korea, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][30..35], 101, race_time_kor + 3.hours
)
create_race_with_participants(
  korea, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][36..41], 107, race_time_kor + 3.hours + 5.minutes
)
create_race_with_participants(
  korea, sprint_type, "Final", "final", "M",
  athletes["M"][30..35], 101, race_time_kor + 3.hours + 15.minutes
)

# Vertical races (next day)
race_time_kor_v = race_time_kor + 1.day
create_race_with_participants(
  korea, vertical_type, "Final", "final", "W",
  athletes["F"][35..64], 201, race_time_kor_v
)
create_race_with_participants(
  korea, vertical_type, "Final", "final", "M",
  athletes["M"][35..64], 301, race_time_kor_v + 2.hours
)

puts "✅ Created South Korea Series races (Sprint, Vertical)"

# ============================================================================
# COMPETITION 10: WORLD CHAMPIONSHIPS LONG DISTANCE TEAM
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 10: World Championships Long Distance Team - #{(base_datetime + 38.days).strftime('%B %d, %Y')}"
puts "=" * 80

wc_ld_start = (base_datetime + 38.days).to_date
wc_ld_end = (base_datetime + 41.days).to_date

wc_ld = Competition.create!(
  name: "ISMF World Championships Long Distance Team",
  description: "Long distance team race",
  start_date: wc_ld_start,
  end_date: wc_ld_end,
  city: "Areches-Beaufort",
  place: "Areches-Beaufort",
  country: "FRA",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_wcld = base_datetime + 38.days + 9.hours

create_team_race(
  wc_ld, team_type, "Final", "final", "MM",
  athletes["M"][0..39], 1, race_time_wcld, 2
)
create_team_race(
  wc_ld, team_type, "Final", "final", "WW",
  athletes["F"][0..39], 101, race_time_wcld + 4.hours, 2
)

puts "✅ Created World Championships Long Distance Team races (Team)"

# ============================================================================
# COMPETITION 11: ASIAN CHAMPIONSHIPS
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 11: Asian Championships - #{(base_datetime + 43.days).strftime('%B %d, %Y')}"
puts "=" * 80

asian_start = (base_datetime + 43.days).to_date
asian_end = (base_datetime + 47.days).to_date

asian = Competition.create!(
  name: "ISMF Asian Championships",
  description: "Asian Championships with all disciplines",
  start_date: asian_start,
  end_date: asian_end,
  city: "Yabuli",
  place: "Yabuli Ski resort, Haerbin, Heilongjiang province",
  country: "CHN",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_asia = base_datetime + 43.days + 10.hours

# Sprint
create_race_with_participants(
  asian, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][0..39], 1, race_time_asia
)
5.times do |i|
  create_race_with_participants(
    asian, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time_asia + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  asian, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][0..5], 1, race_time_asia + 1.hour
)
create_race_with_participants(
  asian, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][6..11], 7, race_time_asia + 1.hour + 5.minutes
)
create_race_with_participants(
  asian, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time_asia + 1.hour + 15.minutes
)

create_race_with_participants(
  asian, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][0..39], 101, race_time_asia + 2.hours
)
5.times do |i|
  create_race_with_participants(
    asian, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time_asia + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  asian, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][0..5], 101, race_time_asia + 3.hours
)
create_race_with_participants(
  asian, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][6..11], 107, race_time_asia + 3.hours + 5.minutes
)
create_race_with_participants(
  asian, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time_asia + 3.hours + 15.minutes
)

# Vertical, Individual, Mixed Relay
race_time_asia_v = race_time_asia + 1.day
create_race_with_participants(
  asian, vertical_type, "Final", "final", "W",
  athletes["F"][10..49], 201, race_time_asia_v
)
create_race_with_participants(
  asian, vertical_type, "Final", "final", "M",
  athletes["M"][10..49], 301, race_time_asia_v + 2.hours
)

race_time_asia_i = race_time_asia + 2.days
create_race_with_participants(
  asian, individual_type, "Final", "final", "W",
  athletes["F"][15..54], 401, race_time_asia_i
)
create_race_with_participants(
  asian, individual_type, "Final", "final", "M",
  athletes["M"][15..54], 501, race_time_asia_i + 2.hours
)

race_time_asia_mr = race_time_asia + 3.days
create_relay_race_with_teams(
  asian, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][20..39], athletes["F"][20..39], 601, race_time_asia_mr, 20
)
create_relay_race_with_teams(
  asian, mixed_relay_type, "Semi-Final 1", "semi_final",
  athletes["M"][20..25], athletes["F"][20..25], 601, race_time_asia_mr + 1.hour, 6
)
create_relay_race_with_teams(
  asian, mixed_relay_type, "Semi-Final 2", "semi_final",
  athletes["M"][26..31], athletes["F"][26..31], 607, race_time_asia_mr + 1.hour + 5.minutes, 6
)
create_relay_race_with_teams(
  asian, mixed_relay_type, "Final", "final",
  athletes["M"][20..25], athletes["F"][20..25], 601, race_time_asia_mr + 2.hours, 6
)

puts "✅ Created Asian Championships races (Mixed Relay, Sprint, Vertical, Individual)"

# ============================================================================
# COMPETITION 12: VAL MARTELLO WORLD CUP
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 12: Val Martello World Cup - #{(base_datetime + 46.days).strftime('%B %d, %Y')}"
puts "=" * 80

martello_start = (base_datetime + 46.days).to_date
martello_end = (base_datetime + 49.days).to_date

martello = Competition.create!(
  name: "ISMF Val Martello World Cup",
  description: "Mixed Relay, Sprint, and Individual races",
  start_date: martello_start,
  end_date: martello_end,
  city: "Val Martello",
  place: "Val Martello",
  country: "ITA",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_mart = base_datetime + 46.days + 10.hours

# Sprint
create_race_with_participants(
  martello, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][20..59], 1, race_time_mart
)
5.times do |i|
  create_race_with_participants(
    martello, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][20 + (i * 6)..20 + (i * 6) + 5], i * 6 + 1, race_time_mart + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  martello, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][20..25], 1, race_time_mart + 1.hour
)
create_race_with_participants(
  martello, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][26..31], 7, race_time_mart + 1.hour + 5.minutes
)
create_race_with_participants(
  martello, sprint_type, "Final", "final", "W",
  athletes["F"][20..25], 1, race_time_mart + 1.hour + 15.minutes
)

create_race_with_participants(
  martello, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][20..59], 101, race_time_mart + 2.hours
)
5.times do |i|
  create_race_with_participants(
    martello, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][20 + (i * 6)..20 + (i * 6) + 5], 101 + i * 6, race_time_mart + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  martello, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][20..25], 101, race_time_mart + 3.hours
)
create_race_with_participants(
  martello, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][26..31], 107, race_time_mart + 3.hours + 5.minutes
)
create_race_with_participants(
  martello, sprint_type, "Final", "final", "M",
  athletes["M"][20..25], 101, race_time_mart + 3.hours + 15.minutes
)

# Individual
race_time_mart_i = race_time_mart + 1.day
create_race_with_participants(
  martello, individual_type, "Final", "final", "W",
  athletes["F"][25..64], 201, race_time_mart_i
)
create_race_with_participants(
  martello, individual_type, "Final", "final", "M",
  athletes["M"][25..64], 301, race_time_mart_i + 2.hours
)

# Mixed Relay
race_time_mart_mr = race_time_mart + 2.days
create_relay_race_with_teams(
  martello, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][30..49], athletes["F"][30..49], 401, race_time_mart_mr, 20
)
create_relay_race_with_teams(
  martello, mixed_relay_type, "Semi-Final 1", "semi_final",
  athletes["M"][30..35], athletes["F"][30..35], 401, race_time_mart_mr + 1.hour, 6
)
create_relay_race_with_teams(
  martello, mixed_relay_type, "Semi-Final 2", "semi_final",
  athletes["M"][36..41], athletes["F"][36..41], 407, race_time_mart_mr + 1.hour + 5.minutes, 6
)
create_relay_race_with_teams(
  martello, mixed_relay_type, "Final", "final",
  athletes["M"][30..35], athletes["F"][30..35], 401, race_time_mart_mr + 2.hours, 6
)

puts "✅ Created Val Martello World Cup races (Mixed Relay, Sprint, Individual)"

# ============================================================================
# COMPETITION 13: PUY-SAINT-VINCENT WORLD CUP
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 13: Puy-Saint-Vincent World Cup - #{(base_datetime + 52.days).strftime('%B %d, %Y')}"
puts "=" * 80

puy_wc_start = (base_datetime + 52.days).to_date
puy_wc_end = (base_datetime + 53.days).to_date

puy_wc = Competition.create!(
  name: "ISMF Puy-Saint-Vincent World Cup",
  description: "Vertical and Individual races",
  start_date: puy_wc_start,
  end_date: puy_wc_end,
  city: "Puy-Saint-Vincent",
  place: "Puy-Saint-Vincent",
  country: "FRA",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_puy = base_datetime + 52.days + 10.hours

create_race_with_participants(
  puy_wc, vertical_type, "Final", "final", "W",
  athletes["F"][0..39], 1, race_time_puy
)
create_race_with_participants(
  puy_wc, vertical_type, "Final", "final", "M",
  athletes["M"][0..39], 101, race_time_puy + 2.hours
)

race_time_puy_i = race_time_puy + 1.day
create_race_with_participants(
  puy_wc, individual_type, "Final", "final", "W",
  athletes["F"][5..44], 201, race_time_puy_i
)
create_race_with_participants(
  puy_wc, individual_type, "Final", "final", "M",
  athletes["M"][5..44], 301, race_time_puy_i + 2.hours
)

puts "✅ Created Puy-Saint-Vincent World Cup races (Vertical, Individual)"

# ============================================================================
# COMPETITION 14: YOUTH WORLD CHAMPIONSHIPS
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 14: Youth World Championships - #{(base_datetime + 52.days).strftime('%B %d, %Y')}"
puts "=" * 80

youth_wc_start = (base_datetime + 52.days).to_date
youth_wc_end = (base_datetime + 56.days).to_date

youth_wc = Competition.create!(
  name: "ISMF Youth World Championships",
  description: "Youth World Championships with all disciplines",
  start_date: youth_wc_start,
  end_date: youth_wc_end,
  city: "Puy-Saint-Vincent",
  place: "Puy-Saint-Vincent",
  country: "FRA",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_youth = base_datetime + 53.days + 10.hours

# Sprint
create_race_with_participants(
  youth_wc, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][40..69], 1, race_time_youth
)
5.times do |i|
  create_race_with_participants(
    youth_wc, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][40 + (i * 6)..40 + (i * 6) + 5], i * 6 + 1, race_time_youth + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  youth_wc, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][40..45], 1, race_time_youth + 1.hour
)
create_race_with_participants(
  youth_wc, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][46..51], 7, race_time_youth + 1.hour + 5.minutes
)
create_race_with_participants(
  youth_wc, sprint_type, "Final", "final", "W",
  athletes["F"][40..45], 1, race_time_youth + 1.hour + 15.minutes
)

create_race_with_participants(
  youth_wc, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][40..69], 101, race_time_youth + 2.hours
)
5.times do |i|
  create_race_with_participants(
    youth_wc, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][40 + (i * 6)..40 + (i * 6) + 5], 101 + i * 6, race_time_youth + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  youth_wc, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][40..45], 101, race_time_youth + 3.hours
)
create_race_with_participants(
  youth_wc, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][46..51], 107, race_time_youth + 3.hours + 5.minutes
)
create_race_with_participants(
  youth_wc, sprint_type, "Final", "final", "M",
  athletes["M"][40..45], 101, race_time_youth + 3.hours + 15.minutes
)

# Vertical, Individual, Mixed Relay
race_time_youth_v = race_time_youth + 1.day
create_race_with_participants(
  youth_wc, vertical_type, "Final", "final", "W",
  athletes["F"][45..74], 201, race_time_youth_v
)
create_race_with_participants(
  youth_wc, vertical_type, "Final", "final", "M",
  athletes["M"][45..74], 301, race_time_youth_v + 2.hours
)

race_time_youth_i = race_time_youth + 2.days
create_race_with_participants(
  youth_wc, individual_type, "Final", "final", "W",
  athletes["F"][50..79], 401, race_time_youth_i
)
create_race_with_participants(
  youth_wc, individual_type, "Final", "final", "M",
  athletes["M"][50..79], 501, race_time_youth_i + 2.hours
)

race_time_youth_mr = race_time_youth + 3.days
create_relay_race_with_teams(
  youth_wc, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][50..69], athletes["F"][50..69], 601, race_time_youth_mr, 20
)
create_relay_race_with_teams(
  youth_wc, mixed_relay_type, "Semi-Final 1", "semi_final",
  athletes["M"][50..55], athletes["F"][50..55], 601, race_time_youth_mr + 1.hour, 6
)
create_relay_race_with_teams(
  youth_wc, mixed_relay_type, "Semi-Final 2", "semi_final",
  athletes["M"][56..61], athletes["F"][56..61], 607, race_time_youth_mr + 1.hour + 5.minutes, 6
)
create_relay_race_with_teams(
  youth_wc, mixed_relay_type, "Final", "final",
  athletes["M"][50..55], athletes["F"][50..55], 601, race_time_youth_mr + 2.hours, 6
)

puts "✅ Created Youth World Championships races (Mixed Relay, Sprint, Vertical, Individual)"

# ============================================================================
# COMPETITION 15: TOUR DU RUTOR EXTREME
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 15: Tour du Rutor Extreme - #{(base_datetime + 55.days).strftime('%B %d, %Y')}"
puts "=" * 80

rutor_start = (base_datetime + 55.days).to_date
rutor_end = (base_datetime + 56.days).to_date

rutor = Competition.create!(
  name: "ISMF Series 4 – Italy / Tour du Rutor Extreme",
  description: "Team race",
  start_date: rutor_start,
  end_date: rutor_end,
  city: "La Thuile",
  place: "La Thuile, Arvier, Valgrisenche - Aosta Valley",
  country: "ITA",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_rutor = base_datetime + 55.days + 9.hours

create_team_race(
  rutor, team_type, "Final", "final", "MM",
  athletes["M"][40..69], 1, race_time_rutor, 2
)
create_team_race(
  rutor, team_type, "Final", "final", "WW",
  athletes["F"][40..69], 101, race_time_rutor + 4.hours, 2
)

puts "✅ Created Tour du Rutor Extreme races (Team)"

# ============================================================================
# COMPETITION 16: VILLARS-SUR-OLLON WORLD CUP
# ============================================================================

puts "\n" + "=" * 80
puts "Competition 16: Villars-sur-Ollon World Cup - #{(base_datetime + 59.days).strftime('%B %d, %Y')}"
puts "=" * 80

villars_start = (base_datetime + 59.days).to_date
villars_end = (base_datetime + 63.days).to_date

villars = Competition.create!(
  name: "ISMF Villars-sur-Ollon World Cup",
  description: "Final World Cup with all disciplines",
  start_date: villars_start,
  end_date: villars_end,
  city: "Villars-sur-Ollon",
  place: "Villars-sur-Ollon",
  country: "CHE",
  webpage_url: "https://www.ismf-ski.org"
)

race_time_vil = base_datetime + 59.days + 10.hours

# Sprint
create_race_with_participants(
  villars, sprint_type, "Qualifications", "qualification", "W",
  athletes["F"][0..49], 1, race_time_vil
)
5.times do |i|
  create_race_with_participants(
    villars, sprint_type, "Heat #{i + 1}", "heat", "W",
    athletes["F"][(i * 6)...(i * 6 + 6)], i * 6 + 1, race_time_vil + 30.minutes + (i * 5).minutes
  )
end
create_race_with_participants(
  villars, sprint_type, "Semi-Final 1", "semi_final", "W",
  athletes["F"][0..5], 1, race_time_vil + 1.hour
)
create_race_with_participants(
  villars, sprint_type, "Semi-Final 2", "semi_final", "W",
  athletes["F"][6..11], 7, race_time_vil + 1.hour + 5.minutes
)
create_race_with_participants(
  villars, sprint_type, "Final", "final", "W",
  athletes["F"][0..5], 1, race_time_vil + 1.hour + 15.minutes
)

create_race_with_participants(
  villars, sprint_type, "Qualifications", "qualification", "M",
  athletes["M"][0..49], 101, race_time_vil + 2.hours
)
5.times do |i|
  create_race_with_participants(
    villars, sprint_type, "Heat #{i + 1}", "heat", "M",
    athletes["M"][(i * 6)...(i * 6 + 6)], 101 + i * 6, race_time_vil + 2.5.hours + (i * 5).minutes
  )
end
create_race_with_participants(
  villars, sprint_type, "Semi-Final 1", "semi_final", "M",
  athletes["M"][0..5], 101, race_time_vil + 3.hours
)
create_race_with_participants(
  villars, sprint_type, "Semi-Final 2", "semi_final", "M",
  athletes["M"][6..11], 107, race_time_vil + 3.hours + 5.minutes
)
create_race_with_participants(
  villars, sprint_type, "Final", "final", "M",
  athletes["M"][0..5], 101, race_time_vil + 3.hours + 15.minutes
)

# Vertical
race_time_vil_v = race_time_vil + 1.day
create_race_with_participants(
  villars, vertical_type, "Final", "final", "W",
  athletes["F"][10..59], 201, race_time_vil_v
)
create_race_with_participants(
  villars, vertical_type, "Final", "final", "M",
  athletes["M"][10..59], 301, race_time_vil_v + 2.hours
)

# Individual
race_time_vil_i = race_time_vil + 2.days
create_race_with_participants(
  villars, individual_type, "Final", "final", "W",
  athletes["F"][15..64], 401, race_time_vil_i
)
create_race_with_participants(
  villars, individual_type, "Final", "final", "M",
  athletes["M"][15..64], 501, race_time_vil_i + 2.hours
)

# Mixed Relay
race_time_vil_mr = race_time_vil + 3.days
create_relay_race_with_teams(
  villars, mixed_relay_type, "Qualifications", "qualification",
  athletes["M"][20..39], athletes["F"][20..39], 601, race_time_vil_mr, 20
)
create_relay_race_with_teams(
  villars, mixed_relay_type, "Semi-Final 1", "semi_final",
  athletes["M"][20..25], athletes["F"][20..25], 601, race_time_vil_mr + 1.hour, 6
)
create_relay_race_with_teams(
  villars, mixed_relay_type, "Semi-Final 2", "semi_final",
  athletes["M"][26..31], athletes["F"][26..31], 607, race_time_vil_mr + 1.hour + 5.minutes, 6
)
create_relay_race_with_teams(
  villars, mixed_relay_type, "Final", "final",
  athletes["M"][20..25], athletes["F"][20..25], 601, race_time_vil_mr + 2.hours, 6
)

puts "✅ Created Villars-sur-Ollon World Cup races (Mixed Relay, Sprint, Vertical, Individual)"

# ============================================================================
# SUMMARY
# ============================================================================

puts ""
puts "=" * 80
puts "2026 ISMF World Cup Competitions Summary"
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
  
  completed = comp.races.where(status: "completed").count
  in_progress = comp.races.where(status: "in_progress").count
  scheduled = comp.races.where(status: "scheduled").count
  
  puts "  Status: #{completed} completed, #{in_progress} in progress, #{scheduled} upcoming"
  puts ""
end

puts "✅ Seed data created successfully!"
puts ""