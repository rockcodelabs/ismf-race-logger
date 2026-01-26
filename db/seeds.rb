# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create admin user
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@ismf-ski.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "password123")
admin_name = ENV.fetch("ADMIN_NAME", "ISMF Admin")

admin = User.find_or_initialize_by(email_address: admin_email)
admin.assign_attributes(
  name: admin_name,
  password: admin_password,
  password_confirmation: admin_password,
  admin: true
)

if admin.save
  puts "✅ Admin user created/updated: #{admin.email_address}"
else
  puts "❌ Failed to create admin user: #{admin.errors.full_messages.join(', ')}"
end

# Create a regular test user in development
if Rails.env.development?
  test_user = User.find_or_initialize_by(email_address: "user@example.com")
  test_user.assign_attributes(
    name: "Test User",
    password: "password123",
    password_confirmation: "password123",
    admin: false
  )

  if test_user.save
    puts "✅ Test user created/updated: #{test_user.email_address}"
  else
    puts "❌ Failed to create test user: #{test_user.errors.full_messages.join(', ')}"
  end
end

puts "Seeding completed!"