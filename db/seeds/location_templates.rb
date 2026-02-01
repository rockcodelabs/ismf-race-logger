# frozen_string_literal: true

# ============================================================================
# RACE TYPE LOCATION TEMPLATES
# ============================================================================

puts "\nCreating location templates for race types..."

# Clear existing templates
RaceTypeLocationTemplate.delete_all

# Get race types
sprint_type = RaceType.find_by(name: "Sprint")
mixed_relay_type = RaceType.find_by(name: "Mixed Relay")
individual_type = RaceType.find_by(name: "Individual")
vertical_type = RaceType.find_by(name: "Vertical")
team_type = RaceType.find_by(name: "Team")

# Sprint and Mixed Relay locations (detailed)
sprint_and_relay_locations = [
  { name: "Start", course_segment: "start", segment_position: "start", display_order: 1, is_standard: true, description: "Starting line" },
  { name: "Foot Loop Start", course_segment: "ascent", segment_position: "foot_start", display_order: 2, is_standard: true, description: "Beginning of foot ascent section" },
  { name: "Foot Loop End", course_segment: "ascent", segment_position: "foot_end", display_order: 3, is_standard: true, description: "End of foot ascent section" },
  { name: "Downhill Start", course_segment: "descent", segment_position: "descent_start", display_order: 4, is_standard: true, description: "Beginning of downhill section" },
  { name: "Downhill Gate", course_segment: "descent", segment_position: "gate", display_order: 5, is_standard: false, description: "Control gate on downhill" },
  { name: "Corridor", course_segment: "finish", segment_position: "corridor", display_order: 6, is_standard: true, description: "Final corridor before finish" },
  { name: "Finish Line", course_segment: "finish", segment_position: "finish", display_order: 7, is_standard: true, description: "Finish line" }
]

# Create Sprint templates
if sprint_type
  sprint_and_relay_locations.each do |loc_data|
    RaceTypeLocationTemplate.create!(
      race_type: sprint_type,
      name: loc_data[:name],
      course_segment: loc_data[:course_segment],
      segment_position: loc_data[:segment_position],
      display_order: loc_data[:display_order],
      is_standard: loc_data[:is_standard],
      description: loc_data[:description]
    )
  end
  puts "  ✓ Sprint: 7 location templates"
end

# Create Mixed Relay templates (same as Sprint + second loop)
if mixed_relay_type
  sprint_and_relay_locations.each do |loc_data|
    RaceTypeLocationTemplate.create!(
      race_type: mixed_relay_type,
      name: loc_data[:name],
      course_segment: loc_data[:course_segment],
      segment_position: loc_data[:segment_position],
      display_order: loc_data[:display_order],
      is_standard: loc_data[:is_standard],
      description: loc_data[:description]
    )
  end
  
  # Add second loop locations
  second_loop_locations = [
    { name: "Loop 2 - Foot Start", course_segment: "ascent", segment_position: "foot_start_2", display_order: 8, is_standard: true, description: "Second loop foot ascent start" },
    { name: "Loop 2 - Foot End", course_segment: "ascent", segment_position: "foot_end_2", display_order: 9, is_standard: true, description: "Second loop foot ascent end" },
    { name: "Loop 2 - Downhill Start", course_segment: "descent", segment_position: "descent_start_2", display_order: 10, is_standard: true, description: "Second loop downhill start" },
    { name: "Handover", course_segment: "transition", segment_position: "handover", display_order: 11, is_standard: true, description: "Relay handover zone" }
  ]
  
  second_loop_locations.each do |loc_data|
    RaceTypeLocationTemplate.create!(
      race_type: mixed_relay_type,
      name: loc_data[:name],
      course_segment: loc_data[:course_segment],
      segment_position: loc_data[:segment_position],
      display_order: loc_data[:display_order],
      is_standard: loc_data[:is_standard],
      description: loc_data[:description]
    )
  end
  puts "  ✓ Mixed Relay: 11 location templates (7 base + 4 second loop)"
end

# Simple locations for Individual, Vertical, and Team (just Start and Finish)
simple_locations = [
  { name: "Start", course_segment: "start", segment_position: "start", display_order: 1, is_standard: true, description: "Starting line" },
  { name: "Finish Line", course_segment: "finish", segment_position: "finish", display_order: 2, is_standard: true, description: "Finish line" }
]

[individual_type, vertical_type, team_type].compact.each do |race_type|
  simple_locations.each do |loc_data|
    RaceTypeLocationTemplate.create!(
      race_type: race_type,
      name: loc_data[:name],
      course_segment: loc_data[:course_segment],
      segment_position: loc_data[:segment_position],
      display_order: loc_data[:display_order],
      is_standard: loc_data[:is_standard],
      description: loc_data[:description]
    )
  end
  puts "  ✓ #{race_type.name}: 2 location templates"
end

puts "✅ Created location templates for all race types"