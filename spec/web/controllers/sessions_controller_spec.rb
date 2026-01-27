# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Web::Controllers::SessionsController, type: :request do
  describe 'GET /session/new' do
    it 'returns success' do
      get new_session_path
      expect(response).to have_http_status(:success)
    end

    it 'renders the sign in form' do
      get new_session_path
      expect(response.body).to include('Sign In')
      expect(response.body).to include('Email Address')
      expect(response.body).to include('Password')
    end
  end

  describe 'POST /session' do
    context 'with valid credentials' do
      let!(:user_record) do
        Infrastructure::Persistence::Records::UserRecord.create!(
          email_address: 'user@example.com',
          name: 'Test User',
          password: 'password123',
          password_confirmation: 'password123',
          admin: false
        )
      end

      it 'creates a session' do
        expect {
          post session_path, params: {
            email_address: 'user@example.com',
            password: 'password123'
          }
        }.to change(Infrastructure::Persistence::Records::SessionRecord, :count).by(1)
      end

      it 'redirects to root path' do
        post session_path, params: {
          email_address: 'user@example.com',
          password: 'password123'
        }

        expect(response).to redirect_to(root_path)
      end

      it 'sets session cookie' do
        post session_path, params: {
          email_address: 'user@example.com',
          password: 'password123'
        }

        expect(cookies[:session_id]).to be_present
      end

      context 'with admin user' do
        let!(:admin_record) do
          Infrastructure::Persistence::Records::UserRecord.create!(
            email_address: 'admin@example.com',
            name: 'Admin User',
            password: 'password123',
            password_confirmation: 'password123',
            admin: true
          )
        end

        it 'authenticates and creates session' do
          post session_path, params: {
            email_address: 'admin@example.com',
            password: 'password123'
          }

          expect(response).to redirect_to(root_path)
          session_record = Infrastructure::Persistence::Records::SessionRecord.last
          expect(session_record.user_record).to eq(admin_record)
        end
      end

      context 'with user having a role' do
        let!(:role_record) do
          Infrastructure::Persistence::Records::RoleRecord.create!(
            name: 'national_referee'
          )
        end

        let!(:referee_record) do
          Infrastructure::Persistence::Records::UserRecord.create!(
            email_address: 'referee@example.com',
            name: 'Referee User',
            password: 'password123',
            password_confirmation: 'password123',
            role_id: role_record.id
          )
        end

        it 'authenticates referee user' do
          post session_path, params: {
            email_address: 'referee@example.com',
            password: 'password123'
          }

          expect(response).to redirect_to(root_path)
          session_record = Infrastructure::Persistence::Records::SessionRecord.last
          expect(session_record.user_record.role_record.name).to eq('national_referee')
        end
      end
    end

    context 'with invalid credentials' do
      let!(:user_record) do
        Infrastructure::Persistence::Records::UserRecord.create!(
          email_address: 'user@example.com',
          name: 'Test User',
          password: 'password123',
          password_confirmation: 'password123'
        )
      end

      it 'does not create a session with wrong password' do
        expect {
          post session_path, params: {
            email_address: 'user@example.com',
            password: 'wrongpassword'
          }
        }.not_to change(Infrastructure::Persistence::Records::SessionRecord, :count)
      end

      it 'redirects to sign in with alert for wrong password' do
        post session_path, params: {
          email_address: 'user@example.com',
          password: 'wrongpassword'
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Try another email address or password')
      end

      it 'fails with non-existent email' do
        post session_path, params: {
          email_address: 'nonexistent@example.com',
          password: 'password123'
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Try another email address or password')
      end

      it 'fails with empty password' do
        post session_path, params: {
          email_address: 'user@example.com',
          password: ''
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Invalid email or password format')
      end

      it 'fails with short password' do
        post session_path, params: {
          email_address: 'user@example.com',
          password: 'short'
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Invalid email or password format')
      end

      it 'fails with invalid email format' do
        post session_path, params: {
          email_address: 'not-an-email',
          password: 'password123'
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Invalid email or password format')
      end
    end

    context 'rate limiting', :skip_rate_limit do
      let!(:user_record) do
        Infrastructure::Persistence::Records::UserRecord.create!(
          email_address: 'user@example.com',
          name: 'Test User',
          password: 'password123',
          password_confirmation: 'password123'
        )
      end

      # Note: Rate limiting test might need special configuration
      # This is a placeholder for rate limit testing
      it 'rate limits excessive login attempts' do
        # Skip or configure rate limiting for tests
        pending "Rate limiting configuration needed for testing"
      end
    end
  end

  describe 'DELETE /session' do
    let!(:user_record) do
      Infrastructure::Persistence::Records::UserRecord.create!(
        email_address: 'user@example.com',
        name: 'Test User',
        password: 'password123',
        password_confirmation: 'password123'
      )
    end

    before do
      post session_path, params: {
        email_address: 'user@example.com',
        password: 'password123'
      }
    end

    it 'destroys the session' do
      expect {
        delete session_path
      }.to change(Infrastructure::Persistence::Records::SessionRecord, :count).by(-1)
    end

    it 'redirects to sign in page' do
      delete session_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'clears session cookie' do
      delete session_path
      expect(cookies[:session_id]).to be_blank
    end

    it 'prevents access after logout' do
      delete session_path

      # Try to access protected resource
      get admin_root_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe 'authentication protection' do
    context 'when accessing admin area without session' do
      it 'redirects to sign in' do
        get admin_root_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context 'when accessing admin area with valid session' do
      let!(:admin_record) do
        Infrastructure::Persistence::Records::UserRecord.create!(
          email_address: 'admin@example.com',
          name: 'Admin User',
          password: 'password123',
          password_confirmation: 'password123',
          admin: true
        )
      end

      before do
        post session_path, params: {
          email_address: 'admin@example.com',
          password: 'password123'
        }
      end

      it 'allows access' do
        get admin_root_path
        expect(response).to have_http_status(:success)
      end
    end

    context 'when regular user tries to access admin area' do
      let!(:user_record) do
        Infrastructure::Persistence::Records::UserRecord.create!(
          email_address: 'user@example.com',
          name: 'Regular User',
          password: 'password123',
          password_confirmation: 'password123',
          admin: false
        )
      end

      before do
        post session_path, params: {
          email_address: 'user@example.com',
          password: 'password123'
        }
      end

      it 'redirects with unauthorized message' do
        get admin_root_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        # Check that either the response body or flash contains the unauthorized message
        expect(response.body.include?('Not authorized') || flash[:alert].present?).to be true
      end
    end
  end

  describe 'integration with application layer' do
    let!(:user_record) do
      Infrastructure::Persistence::Records::UserRecord.create!(
        email_address: 'user@example.com',
        name: 'Test User',
        password: 'password123',
        password_confirmation: 'password123'
      )
    end

    it 'uses Authenticate command for authentication' do
      # This test verifies the controller uses the application layer
      command_double = instance_double(Application::Commands::Users::Authenticate)
      allow(Application::Commands::Users::Authenticate).to receive(:new).and_return(command_double)

      user_entity = Domain::Entities::User.new(
        id: user_record.id,
        email_address: 'user@example.com',
        name: 'Test User',
        admin: false
      )

      expect(command_double).to receive(:call)
        .with(email_address: 'user@example.com', password: 'password123')
        .and_return(Dry::Monads::Success(user_entity))

      post session_path, params: {
        email_address: 'user@example.com',
        password: 'password123'
      }

      expect(response).to redirect_to(root_path)
    end

    it 'handles command failure gracefully' do
      command_double = instance_double(Application::Commands::Users::Authenticate)
      allow(Application::Commands::Users::Authenticate).to receive(:new).and_return(command_double)

      expect(command_double).to receive(:call)
        .and_return(Dry::Monads::Failure(:invalid_credentials))

      post session_path, params: {
        email_address: 'user@example.com',
        password: 'wrongpassword'
      }

      expect(response).to redirect_to(new_session_path)
    end
  end
end