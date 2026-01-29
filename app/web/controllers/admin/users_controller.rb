# frozen_string_literal: true


module Web
  module Controllers
    module Admin
      # UsersController - Admin CRUD for users
      #
      # Uses repos for read operations (returning structs) and AR User model
      # for write operations (forms need AR objects for validation errors).
      #
      # Pattern:
      # - Index: Use repos → structs (immutable, presentation-ready)
      # - Show/Edit: Use AR model (needs associations like sessions)
      # - New/Create/Update: Use AR model (form_with needs AR for errors)
      #
      # Note: We use explicit container access instead of Import[] because
      # Rails controllers have their own initialization requirements.
      #
      class UsersController < BaseController
        before_action :set_user, only: [ :edit, :update, :destroy ]

        def index
          @users = user_repo.all
        end

        def show
          # Load AR model to access associations (sessions)
          @user = User.find(params[:id])
        end

        def new
          @user = User.new
        end

        def create
          @user = User.new(user_params)
          @user.admin = params[:user][:admin] == "1" || params[:user][:admin] == true

          if @user.save
            redirect_to admin_user_path(@user), notice: "User was successfully created."
          else
            render :new, status: :unprocessable_entity
          end
        end

        def edit
          # For edit, we need the AR model for form_with
          @user = User.find(params[:id])
        end

        def update
          # @user is a struct from before_action, need AR model for update
          user_record = User.find(params[:id])
          user_record.assign_attributes(user_params)
          user_record.admin = params[:user][:admin] == "1" || params[:user][:admin] == true

          if user_record.save
            redirect_to admin_user_path(user_record), notice: "User was successfully updated."
          else
            @user = user_record
            render :edit, status: :unprocessable_entity
          end
        end

        def destroy
          user_record = User.find(params[:id])

          if user_record == Current.user
            redirect_to admin_users_path, alert: "You cannot delete yourself."
          else
            user_record.destroy
            redirect_to admin_users_path, notice: "User was successfully deleted."
          end
        end

        private

        def set_user
          @user = user_repo.find!(params[:id])
        end

        def user_params
          params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
        end

        def user_repo
          @user_repo ||= AppContainer["repos.user"]
        end
      end
    end
  end
end
