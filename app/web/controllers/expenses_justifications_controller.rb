# frozen_string_literal: true

module Web
  module Controllers
    # ExpensesJustificationsController - User-facing controller for expense justifications
    #
    # Handles expense justification management for regular users:
    # - Users can view their own expense justifications
    # - Users can create new expense justifications (auto-filled from profile)
    # - Users can edit their own drafts
    # - Users can submit drafts for approval
    # - Users can delete their own drafts
    #
    # Authorization: Pundit (ExpensesJustificationPolicy)
    # Real-time updates: Turbo Streams via ExpensesJustificationBroadcaster
    #
    class ExpensesJustificationsController < ApplicationController
      include Dry::Monads[:result]

      before_action :set_expenses_justification, only: [:show, :edit, :update, :destroy, :submit]
      before_action :authorize_expenses_justification, only: [:show, :edit, :update, :destroy, :submit]
      after_action :verify_authorized

      # GET /expenses_justifications
      # List user's own expense justifications
      def index
        authorize ExpensesJustification

        repo = AppContainer["repos.expenses_justification"]
        @expenses_justifications = repo.for_user(Current.user.id)
        @parts_factory = AppContainer["parts.factory"]
      end

      # GET /expenses_justifications/:id
      # Show expense justification details
      def show
        repo = AppContainer["repos.expenses_justification"]
        @expenses_justification = repo.find(params[:id])
        @parts_factory = AppContainer["parts.factory"]
      end

      # GET /expenses_justifications/new
      # New expense justification form
      def new
        authorize ExpensesJustification

        repo = AppContainer["repos.competition"]
        @competitions = repo.all
        @parts_factory = AppContainer["parts.factory"]

        # New ActiveRecord instance for form (auto-filled from user profile)
        @expenses_justification = ExpensesJustification.new(
          user_id: Current.user.id,
          name: Current.user.full_name || Current.user.name,
          address: Current.user.address,
          identity_document_number: Current.user.identity_document_number,
          bank_swift: Current.user.bank_swift,
          bank_iban: Current.user.bank_iban,
          country: Current.user.country,
          travel_start_date: Date.current,
          travel_end_date: Date.current,
          travel_days: 1,
          total_amount: BigDecimal("0.0"),
          status: "draft"
        )
      end

      # POST /expenses_justifications
      # Create new expense justification
      def create
        authorize ExpensesJustification

        save_to_profile = params[:save_to_profile] == "1"

        operation = Operations::ExpensesJustifications::Create.new
        result = operation.call(
          expenses_justification_params.to_h.merge(user_id: Current.user.id),
          save_to_profile: save_to_profile
        )

        case result
        in Success(expenses_justification)
          redirect_to expenses_justification_path(expenses_justification.id),
                      notice: "Expense justification created successfully."
        in Failure(errors)
          repo = AppContainer["repos.competition"]
          @competitions = repo.all
          @parts_factory = AppContainer["parts.factory"]
          @errors = errors
          flash.now[:alert] = "Failed to create expense justification."
          render :new, status: :unprocessable_entity
        end
      end

      # GET /expenses_justifications/:id/edit
      # Edit expense justification form
      def edit
        repo = AppContainer["repos.expenses_justification"]
        @expenses_justification = repo.find(params[:id])

        comp_repo = AppContainer["repos.competition"]
        @competitions = comp_repo.all
        @parts_factory = AppContainer["parts.factory"]
      end

      # PATCH /expenses_justifications/:id
      # Update expense justification
      def update
        save_to_profile = params[:save_to_profile] == "1"

        operation = Operations::ExpensesJustifications::Update.new
        result = operation.call(
          id: params[:id],
          params: expenses_justification_params.to_h,
          current_user: Current.user,
          save_to_profile: save_to_profile
        )

        case result
        in Success(expenses_justification)
          redirect_to expenses_justification_path(expenses_justification.id),
                      notice: "Expense justification updated successfully."
        in Failure(:not_found)
          redirect_to expenses_justifications_path, alert: "Expense justification not found."
        in Failure(:cannot_edit_after_submission)
          redirect_to expenses_justification_path(params[:id]),
                      alert: "Cannot edit after submission. Please contact ISMF staff if changes are needed."
        in Failure(errors)
          repo = AppContainer["repos.expenses_justification"]
          @expenses_justification = repo.find(params[:id])
          comp_repo = AppContainer["repos.competition"]
          @competitions = comp_repo.all
          @parts_factory = AppContainer["parts.factory"]
          @errors = errors
          flash.now[:alert] = "Failed to update expense justification."
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /expenses_justifications/:id
      # Delete expense justification (drafts only)
      def destroy
        record = ExpensesJustification.find(params[:id])
        record.destroy!

        broadcaster = AppContainer["broadcasters.expenses_justification"]
        broadcaster.deleted(record)

        redirect_to expenses_justifications_path, notice: "Expense justification deleted successfully."
      rescue ActiveRecord::RecordNotFound
        redirect_to expenses_justifications_path, alert: "Expense justification not found."
      end

      # PATCH /expenses_justifications/:id/submit
      # Submit expense justification for approval
      def submit
        operation = Operations::ExpensesJustifications::Submit.new
        result = operation.call(id: params[:id], current_user: Current.user)

        case result
        in Success(expenses_justification)
          redirect_to expenses_justification_path(expenses_justification.id),
                      notice: "Expense justification submitted successfully. You will be notified when it's reviewed."
        in Failure(:not_found)
          redirect_to expenses_justifications_path, alert: "Expense justification not found."
        in Failure(:unauthorized)
          redirect_to expenses_justifications_path, alert: "You are not authorized to submit this expense justification."
        in Failure(:cannot_submit)
          redirect_to expenses_justification_path(params[:id]),
                      alert: "Cannot submit this expense justification. It may have already been submitted."
        in Failure(errors)
          redirect_to expenses_justification_path(params[:id]),
                      alert: "Failed to submit: #{errors.values.flatten.join(', ')}"
        end
      end

      private

      def set_expenses_justification
        @expenses_justification_record = ExpensesJustification.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        redirect_to expenses_justifications_path, alert: "Expense justification not found."
      end

      def authorize_expenses_justification
        authorize @expenses_justification_record
      end

      def expenses_justification_params
        params.require(:expenses_justification).permit(
          :competition_id,
          :name,
          :address,
          :identity_document_number,
          :bank_swift,
          :bank_iban,
          :reason_of_travel,
          :charged_of,
          :place,
          :country,
          :travel_start_date,
          :travel_end_date,
          :travel_days,
          :total_amount,
          :regular_transport,
          :private_vehicle,
          :car_rental,
          :other_travelling,
          :allowances,
          :accommodation,
          :special_expenses,
          invoices: []
        )
      end
    end
  end
end