# frozen_string_literal: true

# ============================================================================
# USERS
# ============================================================================

# Get roles for assignment
referee_manager_role = Role.find_by(name: "referee_manager")
var_operator_role = Role.find_by(name: "var_operator")
national_referee_role = Role.find_by(name: "national_referee")
international_referee_role = Role.find_by(name: "international_referee")
jury_president_role = Role.find_by(name: "jury_president")
broadcast_viewer_role = Role.find_by(name: "broadcast_viewer")
broadcast_referee_role = Role.find_by(name: "broadcast_referee")
ismf_staff_role = Role.find_by(name: "ismf_staff")

# Create PIN-enabled users
puts "\nCreating PIN-enabled users..."

users_data = [
  { name: "Dariusz Finster", email: "dariusz.finster@gmail.com", role: var_operator_role, admin: true },
  { name: "Youri", email: "var.operator@ismf-ski.com", role: var_operator_role, admin: false },
  { name: "Oriol Montero", email: "oriol.montero@ismf-ski.com", role: referee_manager_role, admin: false },
  { name: "Laurent Perruchon", email: "laurent.perruchon@ismf-ski.com", role: national_referee_role, admin: false },
  { name: "Brent Harris", email: "brent.harris@ismf-ski.com", role: jury_president_role, admin: false },
  { name: "Christian Schieder", email: "christian.schieder@ismf-ski.com", role: international_referee_role, admin: false },
  { name: "Jordi Millastre", email: "jordi.millastre@ismf-ski.com", role: broadcast_viewer_role, admin: false },
  { name: "Marion Maneglia", email: "marion.maneglia@ismf-ski.com", role: broadcast_referee_role, admin: false },
  { name: "Valeria Ponzo", email: "valeria.ponzo@ismf-ski.org", role: ismf_staff_role, admin: false }
]

users_data.each do |user_data|
  user = User.find_or_initialize_by(email_address: user_data[:email])
  user.assign_attributes(
    name: user_data[:name],
    password: "password123",
    password_confirmation: "password123",
    pin: "1111",
    pin_confirmation: "1111",
    admin: user_data[:admin],
    role: user_data[:role]
  )

  if user.save
    puts "  ✓ #{user.name} (#{user.role&.name}) - PIN: 1111"
  else
    puts "  ✗ Failed to create #{user_data[:name]}: #{user.errors.full_messages.join(', ')}"
  end
end

puts "✅ Created #{users_data.count} PIN-enabled users"