# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  let(:user) { create(:user, password: 'test123', password_confirmation: 'test123') }
  let(:admin) { create(:user, :admin, password: 'test123', password_confirmation: 'test123') }

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
      it 'creates a session' do
        expect {
          post session_path, params: { email_address: user.email_address, password: 'test123' }
        }.to change(Session, :count).by(1)
      end

      it 'redirects to root path' do
        post session_path, params: { email_address: user.email_address, password: 'test123' }
        expect(response).to redirect_to(root_path)
      end

      it 'sets session cookie' do
        post session_path, params: { email_address: user.email_address, password: 'test123' }
        expect(cookies[:session_id]).to be_present
      end

      it 'works for admin users' do
        post session_path, params: { email_address: admin.email_address, password: 'test123' }
        expect(response).to redirect_to(root_path)
        expect(Session.last.user).to eq(admin)
      end
    end

    context 'with invalid credentials' do
      it 'does not create a session' do
        expect {
          post session_path, params: { email_address: user.email_address, password: 'wrong' }
        }.not_to change(Session, :count)
      end

      it 'redirects to sign in with alert' do
        post session_path, params: { email_address: user.email_address, password: 'wrong' }
        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Try another email address or password')
      end

      it 'fails with non-existent email' do
        post session_path, params: { email_address: 'nobody@example.com', password: 'test123' }
        expect(response).to redirect_to(new_session_path)
      end

      it 'fails with empty password' do
        post session_path, params: { email_address: user.email_address, password: '' }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe 'DELETE /session' do
    before do
      post session_path, params: { email_address: user.email_address, password: 'test123' }
    end

    it 'destroys the session' do
      expect {
        delete session_path
      }.to change(Session, :count).by(-1)
    end

    it 'redirects to sign in page' do
      delete session_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'clears session cookie' do
      delete session_path
      expect(cookies[:session_id]).to be_blank
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
      before do
        post session_path, params: { email_address: admin.email_address, password: 'test123' }
      end

      it 'allows access' do
        get admin_root_path
        expect(response).to have_http_status(:success)
      end
    end

    context 'when regular user tries to access admin area' do
      before do
        post session_path, params: { email_address: user.email_address, password: 'test123' }
      end

      it 'redirects with unauthorized message' do
        get admin_root_path
        expect(response).to redirect_to(root_path)
      end
    end
  end
end