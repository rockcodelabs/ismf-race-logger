# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "ISMF Race Logger <onboarding@resend.dev>"
  layout "mailer"
end
