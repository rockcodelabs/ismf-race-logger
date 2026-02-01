# frozen_string_literal: true

# ============================================================================
# RACE TYPES
# ============================================================================

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