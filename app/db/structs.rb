# frozen_string_literal: true

# Structs module namespace for immutable data objects
#
# Contains two types of structs:
#
# 1. Full structs (dry-struct) - For single records
#    - Type-safe with validation and coercion
#    - Include business logic methods
#    - Used by find/find_by/create/update operations
#    - Example: Structs::User
#
# 2. Summary structs (Ruby Data) - For collections
#    - Lightweight and fast (7x faster than dry-struct)
#    - Minimal attributes for list views
#    - Used by all/where/search operations
#    - Example: Structs::UserSummary
#
# Usage:
#   user = Structs::User.new(id: 1, email_address: "test@example.com", ...)
#   summary = Structs::UserSummary.new(1, "test@example.com", "Test User", false)
#
module Structs
end
