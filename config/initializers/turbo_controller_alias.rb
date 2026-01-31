# frozen_string_literal: true

# Turbo Broadcasting Controller Alias
#
# turbo-rails expects ApplicationController to exist at the root namespace
# for rendering partials during broadcasts. Our application uses a namespaced
# controller structure (Web::Controllers::ApplicationController).
#
# This initializer creates an alias so Turbo can find the controller class
# it needs for rendering partials in broadcasts.
#
# See: https://github.com/hotwired/turbo-rails/blob/main/app/channels/turbo/streams/broadcasts.rb#L113
#
# Without this alias, broadcasting fails with:
#   NameError: uninitialized constant Turbo::Streams::Broadcasts::ApplicationController

# Defer creation until after Rails has loaded all controllers
Rails.application.config.after_initialize do
  # Create root-level ApplicationController constant pointing to our namespaced controller
  ApplicationController = Web::Controllers::ApplicationController unless defined?(ApplicationController)
end