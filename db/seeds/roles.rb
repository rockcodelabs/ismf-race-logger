# frozen_string_literal: true

# ============================================================================
# ROLES
# ============================================================================

puts "Creating roles..."
roles_data = [
  "var_operator",
  "national_referee",
  "international_referee",
  "jury_president",
  "referee_manager",
  "broadcast_viewer",
  "broadcast_referee"
]

roles_data.each do |role_name|
  role = Role.find_or_create_by(name: role_name)
  puts "  ✓ #{role.name}"
end
puts "✅ Created #{Role.count} roles"