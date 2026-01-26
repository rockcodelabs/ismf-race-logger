# frozen_string_literal: true

# Custom Pundit matchers for RSpec
# Usage:
#   it { is_expected.to permit_action(:index) }
#   it { is_expected.not_to permit_action(:destroy) }

RSpec::Matchers.define :permit_action do |action|
  match do |policy|
    policy.public_send("#{action}?")
  end

  failure_message do |policy|
    "Expected #{policy.class} to permit #{action} for #{policy.user.inspect}, but it didn't"
  end

  failure_message_when_negated do |policy|
    "Expected #{policy.class} not to permit #{action} for #{policy.user.inspect}, but it did"
  end
end

RSpec::Matchers.define :permit_actions do |*actions|
  match do |policy|
    actions.all? { |action| policy.public_send("#{action}?") }
  end

  failure_message do |policy|
    failed = actions.reject { |action| policy.public_send("#{action}?") }
    "Expected #{policy.class} to permit #{failed.join(', ')} for #{policy.user.inspect}, but it didn't"
  end

  failure_message_when_negated do |policy|
    permitted = actions.select { |action| policy.public_send("#{action}?") }
    "Expected #{policy.class} not to permit #{permitted.join(', ')} for #{policy.user.inspect}, but it did"
  end
end

RSpec::Matchers.define :forbid_action do |action|
  match do |policy|
    !policy.public_send("#{action}?")
  end

  failure_message do |policy|
    "Expected #{policy.class} to forbid #{action} for #{policy.user.inspect}, but it permitted"
  end

  failure_message_when_negated do |policy|
    "Expected #{policy.class} not to forbid #{action} for #{policy.user.inspect}, but it forbade"
  end
end

RSpec::Matchers.define :forbid_actions do |*actions|
  match do |policy|
    actions.none? { |action| policy.public_send("#{action}?") }
  end

  failure_message do |policy|
    permitted = actions.select { |action| policy.public_send("#{action}?") }
    "Expected #{policy.class} to forbid #{permitted.join(', ')} for #{policy.user.inspect}, but it permitted"
  end

  failure_message_when_negated do |policy|
    forbidden = actions.reject { |action| policy.public_send("#{action}?") }
    "Expected #{policy.class} not to forbid #{forbidden.join(', ')} for #{policy.user.inspect}, but it forbade"
  end
end