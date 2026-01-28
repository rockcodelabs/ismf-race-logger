# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create all roles first
puts "Creating roles..."
Role.seed_all!
puts "✅ Created #{Role.count} roles"

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
    role: referee_manager_role
  )

  if dev_user.save
    puts "✅ Developer user created/updated: #{dev_user.email_address} (role: #{dev_user.role&.name})"
  else
    puts "❌ Failed to create developer user: #{dev_user.errors.full_messages.join(', ')}"
  end
end

puts ""
puts "Seeding completed!"
puts "  Total roles: #{Role.count}"
puts "  Total users: #{User.count}"
puts "  Admin users: #{User.admins.count}"
puts "  Referees: #{User.referees.count}"
puts "  VAR operators: #{User.var_operators.count}"
