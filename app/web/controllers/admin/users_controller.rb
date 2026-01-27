# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      class UsersController < BaseController
        before_action :set_user, only: [:show, :edit, :update, :destroy]

        def index
          @users = Infrastructure::Persistence::Records::UserRecord.order(created_at: :desc)
        end

        def show
        end

        def new
          @user = Infrastructure::Persistence::Records::UserRecord.new
        end

        def create
          @user = Infrastructure::Persistence::Records::UserRecord.new(user_params)
          @user.admin = params[:user][:admin] == "1" || params[:user][:admin] == true

          if @user.save
            redirect_to admin_user_path(@user), notice: "User was successfully created."
          else
            render :new, status: :unprocessable_entity
          end
        end

        def edit
        end

        def update
          @user.assign_attributes(user_params)
          @user.admin = params[:user][:admin] == "1" || params[:user][:admin] == true
          
          if @user.save
            redirect_to admin_user_path(@user), notice: "User was successfully updated."
          else
            render :edit, status: :unprocessable_entity
          end
        end

        def destroy
          if @user == Current.user
            redirect_to admin_users_path, alert: "You cannot delete yourself."
          else
            @user.destroy
            redirect_to admin_users_path, notice: "User was successfully deleted."
          end
        end

        private

        def set_user
          @user = Infrastructure::Persistence::Records::UserRecord.find(params[:id])
        end

        def user_params
          params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
        end
      end
    end
  end
end