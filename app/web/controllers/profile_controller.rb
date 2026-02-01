# frozen_string_literal: true

module Web
  module Controllers
    class ProfileController < ApplicationController
      def edit
        @user = Current.user
      end

      def update
        # Filter out blank values - only pass non-blank params
        update_params = {
          user_id: Current.user.id,
          email: params[:email].presence,
          password: params[:password].presence,
          password_confirmation: params[:password_confirmation].presence,
          pin: params[:pin].presence,
          pin_confirmation: params[:pin_confirmation].presence
        }.compact

        result = update_profile_operation.call(**update_params)

        handle_update_result(result)
      end

      private

      def update_profile_operation
        @update_profile_operation ||= Operations::Users::UpdateProfile.new
      end

      def handle_update_result(result)
        result.either(
          ->(user) {
            redirect_to edit_profile_path, notice: "Profile updated successfully."
          },
          ->(error) {
            case error
            in [:validation_failed, errors]
              @user = Current.user
              @errors = errors
              flash.now[:alert] = "Please correct the errors below."
              render :edit, status: :unprocessable_entity
            in :user_not_found
              redirect_to root_path, alert: "User not found."
            in :email_taken
              @user = Current.user
              flash.now[:alert] = "Email address is already taken."
              render :edit, status: :unprocessable_entity
            in [:update_failed, model_errors]
              @user = Current.user
              @errors = model_errors
              flash.now[:alert] = "Failed to update profile."
              render :edit, status: :unprocessable_entity
            else
              redirect_to edit_profile_path, alert: "An error occurred. Please try again."
            end
          }
        )
      end
    end
  end
end