# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # Admin::ExpensesJustificationsController - ISMF staff controller for expense justifications
      #
      # Handles expense justification management for ISMF staff:
      # - ISMF staff can view all expense justifications
      # - ISMF staff can approve/reject submitted expense justifications
      # - ISMF staff can mark approved expenses as paid
      # - ISMF staff have full edit/delete access
      #
      # Authorization: Pundit (ExpensesJustificationPolicy)
      # Real-time updates: Turbo Streams via ExpensesJustificationBroadcaster
      #
      class ExpensesJustificationsController < BaseController
        include Dry::Monads[:result]

        before_action :set_expenses_justification, only: [:show, :edit, :update, :destroy, :approve, :reject, :mark_as_paid]
        before_action :authorize_expenses_justification, only: [:show, :edit, :update, :destroy, :approve, :reject, :mark_as_paid]

        # GET /admin/expenses_justifications
        # List all expense justifications (ISMF staff only)
        def index
          authorize ExpensesJustification

          repo = AppContainer["repos.expenses_justification"]
          
          # Filter by status if provided
          if params[:status].present? && params[:status] != "all"
            @expenses_justifications = repo.by_status(params[:status])
          else
            @expenses_justifications = repo.all
          end

          @parts_factory = AppContainer["parts.factory"]

          # Count by status for filter tabs
          @status_counts = repo.count_by_status
          @unpaid_count = repo.count_approved_unpaid
        end

        # GET /admin/expenses_justifications/:id
        # Show expense justification details (ISMF staff view)
        def show
          repo = AppContainer["repos.expenses_justification"]
          @expenses_justification = repo.find(params[:id])
          @parts_factory = AppContainer["parts.factory"]
        end

        # GET /admin/expenses_justifications/:id/edit
        # Edit expense justification (ISMF staff can edit any status)
        def edit
          repo = AppContainer["repos.expenses_justification"]
          @expenses_justification = repo.find(params[:id])

          comp_repo = AppContainer["repos.competition"]
          @competitions = comp_repo.all
          @parts_factory = AppContainer["parts.factory"]
        end

        # PATCH /admin/expenses_justifications/:id
        # Update expense justification (ISMF staff)
        def update
          operation = Operations::ExpensesJustifications::Update.new
          result = operation.call(
            id: params[:id],
            params: expenses_justification_params.to_h,
            current_user: Current.user,
            save_to_profile: false
          )

          case result
          in Success(expenses_justification)
            redirect_to admin_expenses_justification_path(expenses_justification.id),
                        notice: "Expense justification updated successfully."
          in Failure(:not_found)
            redirect_to admin_expenses_justifications_path, alert: "Expense justification not found."
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

        # DELETE /admin/expenses_justifications/:id
        # Delete expense justification (ISMF staff can delete any)
        def destroy
          record = ExpensesJustification.find(params[:id])
          record.destroy!

          broadcaster = AppContainer["broadcasters.expenses_justification"]
          broadcaster.deleted(record)

          redirect_to admin_expenses_justifications_path, notice: "Expense justification deleted successfully."
        rescue ActiveRecord::RecordNotFound
          redirect_to admin_expenses_justifications_path, alert: "Expense justification not found."
        end

        # PATCH /admin/expenses_justifications/:id/approve
        # Approve expense justification (ISMF staff only)
        def approve
          operation = Operations::ExpensesJustifications::Approve.new
          result = operation.call(id: params[:id], current_user: Current.user)

          case result
          in Success(expenses_justification)
            redirect_to admin_expenses_justification_path(expenses_justification.id),
                        notice: "Expense justification approved successfully. User has been notified."
          in Failure(:not_found)
            redirect_to admin_expenses_justifications_path, alert: "Expense justification not found."
          in Failure(:unauthorized)
            redirect_to admin_expenses_justifications_path, alert: "You are not authorized to approve expense justifications."
          in Failure(:cannot_approve)
            redirect_to admin_expenses_justification_path(params[:id]),
                        alert: "Cannot approve this expense justification. It must be in 'sent' status."
          in Failure(errors)
            redirect_to admin_expenses_justification_path(params[:id]),
                        alert: "Failed to approve: #{errors}"
          end
        end

        # PATCH /admin/expenses_justifications/:id/reject
        # Reject expense justification (ISMF staff only)
        def reject
          operation = Operations::ExpensesJustifications::Reject.new
          result = operation.call(
            id: params[:id],
            current_user: Current.user,
            rejection_reason: params[:rejection_reason]
          )

          case result
          in Success(expenses_justification)
            redirect_to admin_expenses_justification_path(expenses_justification.id),
                        notice: "Expense justification rejected successfully. User has been notified."
          in Failure(:not_found)
            redirect_to admin_expenses_justifications_path, alert: "Expense justification not found."
          in Failure(:unauthorized)
            redirect_to admin_expenses_justifications_path, alert: "You are not authorized to reject expense justifications."
          in Failure(:cannot_reject)
            redirect_to admin_expenses_justification_path(params[:id]),
                        alert: "Cannot reject this expense justification. It must be in 'sent' status."
          in Failure(errors)
            repo = AppContainer["repos.expenses_justification"]
            @expenses_justification = repo.find(params[:id])
            @parts_factory = AppContainer["parts.factory"]
            @errors = errors
            flash.now[:alert] = "Failed to reject: #{errors.values.flatten.join(', ')}"
            render :show, status: :unprocessable_entity
          end
        end

        # PATCH /admin/expenses_justifications/:id/mark_as_paid
        # Mark expense justification as paid (ISMF staff only)
        def mark_as_paid
          operation = Operations::ExpensesJustifications::MarkAsPaid.new
          result = operation.call(id: params[:id], current_user: Current.user)

          case result
          in Success(expenses_justification)
            redirect_to admin_expenses_justification_path(expenses_justification.id),
                        notice: "Expense justification marked as paid successfully."
          in Failure(:not_found)
            redirect_to admin_expenses_justifications_path, alert: "Expense justification not found."
          in Failure(:unauthorized)
            redirect_to admin_expenses_justifications_path, alert: "You are not authorized to mark expenses as paid."
          in Failure(:cannot_mark_as_paid)
            redirect_to admin_expenses_justification_path(params[:id]),
                        alert: "Cannot mark as paid. Expense must be approved and not already paid."
          in Failure(errors)
            redirect_to admin_expenses_justification_path(params[:id]),
                        alert: "Failed to mark as paid: #{errors}"
          end
        end

        private

        def set_expenses_justification
          @expenses_justification_record = ExpensesJustification.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          redirect_to admin_expenses_justifications_path, alert: "Expense justification not found."
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
end