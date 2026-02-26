# frozen_string_literal: true

# Active Record Encryption Configuration
#
# Configures encryption for sensitive database fields.
# Used by ExpensesJustification model to encrypt bank_swift and bank_iban.

Rails.application.config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY") do
  Rails.application.credentials.dig(:active_record_encryption, :primary_key) || 
    "nRdhytLyTLXm1iQyVGL8PQ6C83Vl2zHm" # Default for development/test
end

Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY") do
  Rails.application.credentials.dig(:active_record_encryption, :deterministic_key) || 
    "OMfhmPhXnFtbPLlrlkVT9JRfXm9QoFU7" # Default for development/test
end

Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT") do
  Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt) || 
    "MeGtICmvLVKttHCfULrwfnFnvc1DB2RW" # Default for development/test
end

# Note: For production, set these as environment variables or add to credentials:
# 
# ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=your_production_key
# ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=your_production_deterministic_key
# ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=your_production_salt
#
# Generate production keys with: bin/rails db:encryption:init