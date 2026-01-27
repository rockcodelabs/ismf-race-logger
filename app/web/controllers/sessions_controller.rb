# frozen_string_literal: true

module Web
  module Controllers
    class SessionsController < ApplicationController
      allow_unauthenticated_access only: %i[new create]
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

      def new
      end

      def create
        result = authenticate_user_command.call(
          email_address: params[:email_address],
          password: params[:password]
        )

        handle_authentication_result(result)
      end

      def destroy
        terminate_session
        redirect_to new_session_path, status: :see_other
      end

      private

      def authenticate_user_command
        @authenticate_user_command ||= Operations::Commands::Users::Authenticate.new
      end

      def handle_authentication_result(result)
        result.either(
          ->(user) {
            # Convert domain entity to ActiveRecord for Rails session
            user_record = Infrastructure::Persistence::Records::UserRecord.find(user.id)
            start_new_session_for(user_record)
            redirect_to after_authentication_url
          },
          ->(error) {
            case error
            in [:validation_failed, errors]
              redirect_to new_session_path, alert: "Invalid email or password format."
            in :invalid_credentials
              redirect_to new_session_path, alert: "Try another email address or password."
            else
              redirect_to new_session_path, alert: "Authentication failed. Please try again."
            end
          }
        )
      end
    end
  end
end