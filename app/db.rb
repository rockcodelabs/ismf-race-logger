# frozen_string_literal: true

# DB module namespace for Hanami-hybrid architecture
#
# This module contains:
# - Repos (app/db/repos/) - Data access layer, return structs
# - Structs (app/db/structs/) - Immutable data objects
#
# Usage:
#   user = UserRepo.new.find(1)  # Returns Structs::User or nil
#   users = UserRepo.new.all     # Returns array of Structs::UserSummary
#
module DB
end
