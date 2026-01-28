# frozen_string_literal: true

# UserBroadcaster - Real-time Turbo Stream broadcasts for users
#
# Handles broadcasting user changes to admin dashboard and user management views.
# Wraps structs in Parts before rendering to ensure consistent presentation.
#
# Example:
#   broadcaster = AppContainer["broadcasters.user"]
#   broadcaster.created(user_struct)   # Prepends new user to admin list
#   broadcaster.updated(user_struct)   # Replaces user row in place
#   broadcaster.deleted(user_struct)   # Removes user from DOM
#
class UserBroadcaster < BaseBroadcaster
  # Broadcast when a new user is created
  # Prepends to the users list in admin
  def created(user)
    broadcast_prepend(
      stream_name,
      target: "users",
      partial: "admin/users/user",
      struct: user,
      as: :user
    )
  end

  # Broadcast when a user is updated
  # Replaces the existing user row in place
  def updated(user)
    broadcast_replace(
      stream_name,
      target: dom_id(user),
      partial: "admin/users/user",
      struct: user,
      as: :user
    )
  end

  # Broadcast when a user is deleted
  # Removes the user from the DOM
  def deleted(user)
    broadcast_remove(
      stream_name,
      target: dom_id(user)
    )
  end

  # Broadcast user count update to dashboard
  def count_changed(total_count, admin_count)
    Turbo::StreamsChannel.broadcast_update_to(
      "admin_dashboard",
      target: "user_stats",
      partial: "admin/dashboard/user_stats",
      locals: { total_users: total_count, admin_users: admin_count }
    )
  end

  private

  # Stream name for admin user list updates
  # Clients subscribe with: turbo_stream_from "admin_users"
  def stream_name
    "admin_users"
  end

  # DOM ID for targeting specific users
  def dom_id(user)
    "user_#{user.id}"
  end
end
