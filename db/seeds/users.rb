# frozen_string_literal: true

# ============================================================================
# USERS
# ============================================================================

# Get roles for assignment
referee_manager_role = Role.find_by(name: "referee_manager")
national_referee_role = Role.find_by(name: "national_referee")
international_referee_role = Role.find_by(name: "international_referee")
var_operator_role = Role.find_by(name: "var_operator")
jury_president_role = Role.find_by(name: "jury_president")
broadcast_viewer_role = Role.find_by(name: "broadcast_viewer")
broadcast_referee_role = Role.find_by(name: "broadcast_referee")

# Create PIN-enabled users
puts "\nCreating PIN-enabled users..."

users_data = [
  { name: "Darek Finster", email: "darek.finster@ismf-ski.com", role: var_operator_role, admin: false },
  { name: "Oriol Montero", email: "oriol.montero@ismf-ski.com", role: referee_manager_role, admin: false },
  { name: "Laurent Perruchon", email: "laurent.perruchon@ismf-ski.com", role: national_referee_role, admin: false },
  { name: "Brent Harris", email: "brent.harris@ismf-ski.com", role: jury_president_role, admin: false },
  { name: "Christian Schieder", email: "christian.schieder@ismf-ski.com", role: international_referee_role, admin: false },
  { name: "Jordi Millastre", email: "jordi.millastre@ismf-ski.com", role: broadcast_viewer_role, admin: false },
  { name: "Marion Maneglia", email: "marion.maneglia@ismf-ski.com", role: broadcast_referee_role, admin: false }
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

# Create admin user
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@ismf-ski.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "password123")
admin_name = ENV.fetch("ADMIN_NAME", "ISMF Admin")

admin = User.find_or_initialize_by(email_address: admin_email)
admin.assign_attributes(
  name: admin_name,
  password: admin_password,
  password_confirmation: admin_password,
  pin: "1111",
  pin_confirmation: "1111",
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
    pin: "1111",
    pin_confirmation: "1111",
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
    pin: "1111",
    pin_confirmation: "1111",
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
    pin: "1111",
    pin_confirmation: "1111",
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
    pin: "1111",
    pin_confirmation: "1111",
    admin: true,
    role: var_operator_role
  )

  if dev_user.save
    puts "✅ Developer user created/updated: #{dev_user.email_address} (role: #{dev_user.role&.name})"
  else
    puts "❌ Failed to create developer user: #{dev_user.errors.full_messages.join(', ')}"
  end
end