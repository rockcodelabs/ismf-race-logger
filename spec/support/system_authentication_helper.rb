# frozen_string_literal: true

module SystemAuthenticationHelper
  def sign_in(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_button "Sign In"
  end

  def sign_out(_user = nil)
    delete session_path
  end
end

RSpec.configure do |config|
  config.include SystemAuthenticationHelper, type: :system
end