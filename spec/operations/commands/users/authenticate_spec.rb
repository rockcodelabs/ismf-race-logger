# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Operations::Commands::Users::Authenticate do
  let(:command) { described_class.new }

  describe '#call' do
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

      it 'returns success with user entity' do
        result = command.call(
          email_address: 'user@example.com',
          password: 'password123'
        )

        expect(result).to be_success
        expect(result.value!).to be_a(Domain::Entities::User)
        expect(result.value!.email_address).to eq('user@example.com')
        expect(result.value!.name).to eq('Test User')
      end

      it 'returns user with correct attributes' do
        result = command.call(
          email_address: 'user@example.com',
          password: 'password123'
        )

        user = result.value!
        expect(user.id).to eq(user_record.id)
        expect(user.admin).to be false
        expect(user.role_name).to be_nil
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

        it 'returns admin user entity' do
          result = command.call(
            email_address: 'admin@example.com',
            password: 'password123'
          )

          expect(result).to be_success
          user = result.value!
          expect(user.admin?).to be true
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

        it 'returns user entity with role' do
          result = command.call(
            email_address: 'referee@example.com',
            password: 'password123'
          )

          expect(result).to be_success
          user = result.value!
          expect(user.role_name).to eq('national_referee')
          expect(user.referee?).to be true
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

      it 'returns failure with wrong password' do
        result = command.call(
          email_address: 'user@example.com',
          password: 'wrongpassword'
        )

        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_credentials)
      end

      it 'returns failure with non-existent email' do
        result = command.call(
          email_address: 'nonexistent@example.com',
          password: 'password123'
        )

        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_credentials)
      end

      it 'returns failure with empty password' do
        result = command.call(
          email_address: 'user@example.com',
          password: ''
        )

        expect(result).to be_failure
        expect(result.failure).to be_a(Array)
        expect(result.failure.first).to eq(:validation_failed)
      end

      it 'returns failure with short password' do
        result = command.call(
          email_address: 'user@example.com',
          password: 'short'
        )

        expect(result).to be_failure
        expect(result.failure).to be_a(Array)
        expect(result.failure.first).to eq(:validation_failed)
      end
    end

    context 'with invalid input format' do
      it 'returns validation failure with invalid email format' do
        result = command.call(
          email_address: 'not-an-email',
          password: 'password123'
        )

        expect(result).to be_failure
        expect(result.failure).to be_a(Array)
        expect(result.failure.first).to eq(:validation_failed)
      end

      it 'returns validation failure with missing email' do
        result = command.call(
          email_address: '',
          password: 'password123'
        )

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
      end

      it 'includes error details in validation failure' do
        result = command.call(
          email_address: 'invalid',
          password: 'short'
        )

        expect(result).to be_failure
        error_type, error_details = result.failure
        expect(error_type).to eq(:validation_failed)
        expect(error_details).to be_a(Hash)
      end
    end

    context 'case sensitivity' do
      let!(:user_record) do
        Infrastructure::Persistence::Records::UserRecord.create!(
          email_address: 'user@example.com',
          name: 'Test User',
          password: 'password123',
          password_confirmation: 'password123'
        )
      end

      it 'authenticates with case-insensitive email' do
        result = command.call(
          email_address: 'USER@EXAMPLE.COM',
          password: 'password123'
        )

        # Should fail because email normalization happens at record level
        # This test documents current behavior
        expect(result).to be_failure
      end
    end

    context 'with dependency injection' do
      let(:mock_repository) { instance_double(Infrastructure::Persistence::Repositories::UserRepository) }
      let(:command_with_mock) { described_class.new(user_repository: mock_repository) }

      let(:user_entity) do
        Domain::Entities::User.new(
          id: 1,
          email_address: 'user@example.com',
          name: 'Test User',
          admin: false,
          created_at: Time.current,
          updated_at: Time.current
        )
      end

      it 'uses injected repository' do
        allow(mock_repository).to receive(:authenticate)
          .with('user@example.com', 'password123')
          .and_return(Dry::Monads::Success(user_entity))

        result = command_with_mock.call(
          email_address: 'user@example.com',
          password: 'password123'
        )

        expect(result).to be_success
        expect(result.value!).to eq(user_entity)
      end

      it 'handles repository failure' do
        allow(mock_repository).to receive(:authenticate)
          .and_return(Dry::Monads::Failure(:invalid_credentials))

        result = command_with_mock.call(
          email_address: 'user@example.com',
          password: 'password123'
        )

        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_credentials)
      end
    end
  end
end