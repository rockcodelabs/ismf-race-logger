# frozen_string_literal: true

# Seed Race Type Location Templates
#
# This file creates standardized location templates for each race type.
# These templates are auto-populated to race_locations when a race is created.
#
# Standard locations (is_standard: true): Common positions like Start, Finish, Transitions
# Custom locations (is_standard: false): Example gates/cameras that can be customized per race
#

puts "\n🏔️  Seeding Race Type Location Templates..."

# Helper method to find or create template
def create_or_update_template(race_type, attrs)
  template = RaceTypeLocationTemplate.find_or_initialize_by(
    race_type_id: race_type.id,
    name: attrs[:name]
  )
  template.assign_attributes(attrs)
  template.save!
  template
end

#==============================================================================
# SPRINT RACE TYPE
#==============================================================================
sprint = RaceType.find_by(name: "Sprint")

if sprint
  puts "\n📍 Creating Sprint race location templates..."
  
  sprint_locations = [
    { name: "Start", course_segment: "start_area", segment_position: "full", display_order: 10, is_standard: true, color_code: "gray", description: "Race start area" },
    { name: "Uphill 1 - Start", course_segment: "uphill1", segment_position: "start", display_order: 20, is_standard: true, color_code: "green", description: "Beginning of first uphill section" },
    { name: "Uphill 1 - Middle", course_segment: "uphill1", segment_position: "middle", display_order: 30, is_standard: true, color_code: "green", description: "Mid-point of first uphill" },
    { name: "Uphill 1 - Top", course_segment: "uphill1", segment_position: "top", display_order: 40, is_standard: true, color_code: "green", description: "Top of first uphill section" },
    { name: "Transition 1→2", course_segment: "transition_1to2", segment_position: "full", display_order: 50, is_standard: true, color_code: "blue", description: "Transition area between climbs" },
    { name: "Uphill 2 - Start", course_segment: "uphill2", segment_position: "start", display_order: 60, is_standard: true, color_code: "green", description: "Beginning of second uphill" },
    { name: "Uphill 2 - Top", course_segment: "uphill2", segment_position: "top", display_order: 70, is_standard: true, color_code: "green", description: "Top of second uphill" },
    { name: "Transition 2→1", course_segment: "transition_2to1", segment_position: "full", display_order: 80, is_standard: true, color_code: "blue", description: "Transition to descent" },
    { name: "Descent - Start", course_segment: "descent", segment_position: "start", display_order: 90, is_standard: true, color_code: "red", description: "Top of descent section" },
    { name: "Descent - Middle", course_segment: "descent", segment_position: "middle", display_order: 100, is_standard: true, color_code: "red", description: "Mid-point of descent" },
    { name: "Footpart - Start", course_segment: "footpart", segment_position: "start", display_order: 110, is_standard: true, color_code: "yellow", description: "Beginning of running section" },
    { name: "Footpart - Finish", course_segment: "footpart", segment_position: "end", display_order: 120, is_standard: true, color_code: "yellow", description: "End of running section" },
    { name: "Finish", course_segment: "finish_area", segment_position: "full", display_order: 130, is_standard: true, color_code: "gray", description: "Race finish line" }
  ]
  
  sprint_locations.each do |attrs|
    create_or_update_template(sprint, attrs)
  end
  
  puts "   ✅ Created #{sprint_locations.count} location templates for Sprint"
end

#==============================================================================
# INDIVIDUAL RACE TYPE
#==============================================================================
individual = RaceType.find_by(name: "Individual")

if individual
  puts "\n📍 Creating Individual race location templates..."
  
  individual_locations = [
    { name: "Start", course_segment: "start_area", segment_position: "full", display_order: 10, is_standard: true, color_code: "gray", description: "Race start area" },
    { name: "Uphill 1 - Start", course_segment: "uphill1", segment_position: "start", display_order: 20, is_standard: true, color_code: "green", description: "Beginning of first uphill" },
    { name: "Uphill 1 - Middle", course_segment: "uphill1", segment_position: "middle", display_order: 30, is_standard: true, color_code: "green", description: "Mid-point of first uphill" },
    { name: "Uphill 1 - Top", course_segment: "uphill1", segment_position: "top", display_order: 40, is_standard: true, color_code: "green", description: "Top of first uphill" },
    { name: "Transition 1→2", course_segment: "transition_1to2", segment_position: "full", display_order: 50, is_standard: true, color_code: "blue", description: "First transition area" },
    { name: "Uphill 2 - Start", course_segment: "uphill2", segment_position: "start", display_order: 60, is_standard: true, color_code: "green", description: "Beginning of second uphill" },
    { name: "Uphill 2 - Middle", course_segment: "uphill2", segment_position: "middle", display_order: 70, is_standard: true, color_code: "green", description: "Mid-point of second uphill" },
    { name: "Uphill 2 - Top", course_segment: "uphill2", segment_position: "top", display_order: 80, is_standard: true, color_code: "green", description: "Top of second uphill" },
    { name: "Transition 2→1", course_segment: "transition_2to1", segment_position: "full", display_order: 90, is_standard: true, color_code: "blue", description: "Second transition area" },
    { name: "Descent - Start", course_segment: "descent", segment_position: "start", display_order: 100, is_standard: true, color_code: "red", description: "Top of descent" },
    { name: "Descent - Middle", course_segment: "descent", segment_position: "middle", display_order: 110, is_standard: true, color_code: "red", description: "Mid-point of descent" },
    { name: "Descent - Bottom", course_segment: "descent", segment_position: "bottom", display_order: 120, is_standard: true, color_code: "red", description: "Bottom of descent" },
    { name: "Finish", course_segment: "finish_area", segment_position: "full", display_order: 130, is_standard: true, color_code: "gray", description: "Race finish line" }
  ]
  
  individual_locations.each do |attrs|
    create_or_update_template(individual, attrs)
  end
  
  puts "   ✅ Created #{individual_locations.count} location templates for Individual"
end

#==============================================================================
# VERTICAL RACE TYPE
#==============================================================================
vertical = RaceType.find_by(name: "Vertical")

if vertical
  puts "\n📍 Creating Vertical race location templates..."
  
  vertical_locations = [
    { name: "Start", course_segment: "start_area", segment_position: "full", display_order: 10, is_standard: true, color_code: "gray", description: "Race start area" },
    { name: "Uphill - Start", course_segment: "uphill1", segment_position: "start", display_order: 20, is_standard: true, color_code: "green", description: "Beginning of climb" },
    { name: "Uphill - Lower Third", course_segment: "uphill1", segment_position: "start", display_order: 30, is_standard: true, color_code: "green", description: "Lower third of climb" },
    { name: "Uphill - Middle", course_segment: "uphill1", segment_position: "middle", display_order: 40, is_standard: true, color_code: "green", description: "Mid-point of climb" },
    { name: "Uphill - Upper Third", course_segment: "uphill1", segment_position: "top", display_order: 50, is_standard: true, color_code: "green", description: "Upper third of climb" },
    { name: "Uphill - Top", course_segment: "uphill1", segment_position: "top", display_order: 60, is_standard: true, color_code: "green", description: "Top of climb" },
    { name: "Finish", course_segment: "finish_area", segment_position: "full", display_order: 70, is_standard: true, color_code: "gray", description: "Race finish line" }
  ]
  
  vertical_locations.each do |attrs|
    create_or_update_template(vertical, attrs)
  end
  
  puts "   ✅ Created #{vertical_locations.count} location templates for Vertical"
end

#==============================================================================
# TEAM RACE TYPE (RELAY)
#==============================================================================
team = RaceType.find_by(name: "Team")

if team
  puts "\n📍 Creating Team race location templates..."
  
  team_locations = [
    { name: "Start", course_segment: "start_area", segment_position: "full", display_order: 10, is_standard: true, color_code: "gray", description: "Race start area" },
    { name: "Uphill - Start", course_segment: "uphill1", segment_position: "start", display_order: 20, is_standard: true, color_code: "green", description: "Beginning of uphill" },
    { name: "Uphill - Middle", course_segment: "uphill1", segment_position: "middle", display_order: 30, is_standard: true, color_code: "green", description: "Mid-point of uphill" },
    { name: "Uphill - Top", course_segment: "uphill1", segment_position: "top", display_order: 40, is_standard: true, color_code: "green", description: "Top of uphill" },
    { name: "Transition", course_segment: "transition_1to2", segment_position: "full", display_order: 50, is_standard: true, color_code: "blue", description: "Transition area" },
    { name: "Descent - Start", course_segment: "descent", segment_position: "start", display_order: 60, is_standard: true, color_code: "red", description: "Top of descent" },
    { name: "Descent - Middle", course_segment: "descent", segment_position: "middle", display_order: 70, is_standard: true, color_code: "red", description: "Mid-point of descent" },
    { name: "Finish", course_segment: "finish_area", segment_position: "full", display_order: 80, is_standard: true, color_code: "gray", description: "Race finish line" }
  ]
  
  team_locations.each do |attrs|
    create_or_update_template(team, attrs)
  end
  
  puts "   ✅ Created #{team_locations.count} location templates for Team"
end

#==============================================================================
# MIXED RELAY RACE TYPE
#==============================================================================
mixed_relay = RaceType.find_by(name: "Mixed Relay")

if mixed_relay
  puts "\n📍 Creating Mixed Relay race location templates..."
  
  mixed_relay_locations = [
    { name: "Start", course_segment: "start_area", segment_position: "full", display_order: 10, is_standard: true, color_code: "gray", description: "Race start area" },
    { name: "Uphill - Start", course_segment: "uphill1", segment_position: "start", display_order: 20, is_standard: true, color_code: "green", description: "Beginning of uphill" },
    { name: "Uphill - Middle", course_segment: "uphill1", segment_position: "middle", display_order: 30, is_standard: true, color_code: "green", description: "Mid-point of uphill" },
    { name: "Uphill - Top", course_segment: "uphill1", segment_position: "top", display_order: 40, is_standard: true, color_code: "green", description: "Top of uphill" },
    { name: "Transition", course_segment: "transition_1to2", segment_position: "full", display_order: 50, is_standard: true, color_code: "blue", description: "Transition area" },
    { name: "Descent - Start", course_segment: "descent", segment_position: "start", display_order: 60, is_standard: true, color_code: "red", description: "Top of descent" },
    { name: "Descent - Middle", course_segment: "descent", segment_position: "middle", display_order: 70, is_standard: true, color_code: "red", description: "Mid-point of descent" },
    { name: "Handoff Zone", course_segment: "finish_area", segment_position: "start", display_order: 80, is_standard: true, color_code: "blue", description: "Relay handoff zone" },
    { name: "Finish", course_segment: "finish_area", segment_position: "full", display_order: 90, is_standard: true, color_code: "gray", description: "Race finish line" }
  ]
  
  mixed_relay_locations.each do |attrs|
    create_or_update_template(mixed_relay, attrs)
  end
  
  puts "   ✅ Created #{mixed_relay_locations.count} location templates for Mixed Relay"
end

#==============================================================================
# SUMMARY
#==============================================================================
puts "\n" + "=" * 80
total_templates = RaceTypeLocationTemplate.count
race_types_with_templates = RaceType.joins(:location_templates).distinct.count
puts "✅ Seeding complete!"
puts "   Total location templates: #{total_templates}"
puts "   Race types with templates: #{race_types_with_templates}/#{RaceType.count}"
puts "=" * 80
puts ""