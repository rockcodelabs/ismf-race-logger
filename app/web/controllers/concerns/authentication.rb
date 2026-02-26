# frozen_string_literal: true

module Web
  module Controllers
    module Concerns
      module Authentication
        extend ActiveSupport::Concern

        included do
          before_action :restore_authentication
          before_action :require_authentication
          helper_method :authenticated?
        end

        class_methods do
          def allow_unauthenticated_access(**options)
            skip_before_action :require_authentication, **options
          end
        end

        private
          def authenticated?
            Current.session.present?
          end

          def restore_authentication
            Current.session ||= find_session_by_cookie
          end

          def require_authentication
            restore_authentication
            resume_session || request_authentication
          end

          def resume_session
            Current.session
          end

          def find_session_by_cookie
            Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
          end

          def request_authentication
            session[:return_to_after_authenticating] = request.url
            redirect_to new_session_path
          end

          def after_authentication_url
            return_to = session.delete(:return_to_after_authenticating)
            return return_to if return_to.present?
            
            # Role-based redirect after sign-in
            role_based_redirect_url
          end

          def role_based_redirect_url
            user = Current.user
            return root_url unless user
            
            # Users without a role should go to root
            return root_url unless user.role.present?
            
            # Find active race or next scheduled race
            active_race = Race.find_by(status: "in_progress")
            next_race = active_race || Race.where(status: "scheduled").order(:scheduled_at).first
            
            role_name = user.role.name
            is_management = role_name.in?(%w[var_operator jury_president referee_manager])
            is_admin = user.admin?
            
            # Management roles (var_operator, jury_president, referee_manager)
            # -> Redirect to reports index if there's an active/scheduled race
            # -> Otherwise redirect to dashboard (still accessible, just not in menu)
            if is_management
              return next_race ? admin_race_reports_path(next_race) : admin_root_path
            end
            
            # All other roles (referees, etc.)
            # -> Redirect to new report page if there's an active/scheduled race
            # -> If admin but no race, go to dashboard
            # -> If non-admin and no race, go to root
            if next_race
              new_admin_race_report_path(next_race)
            elsif is_admin
              admin_root_path
            else
              root_url
            end
          end

          def start_new_session_for(user)
            user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
              Current.session = session
              cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
            end
          end

          def terminate_session
            Current.session.destroy
            cookies.delete(:session_id)
          end
      end
    end
  end
end
