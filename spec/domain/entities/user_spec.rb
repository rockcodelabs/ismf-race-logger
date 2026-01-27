# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Domain::Entities::User do
  describe 'initialization' do
    it 'creates a user with required attributes' do
      user = described_class.new(
        id: 1,
        email_address: 'test@example.com',
        name: 'Test User',
        admin: false,
        created_at: Time.current,
        updated_at: Time.current
      )

      expect(user.email_address).to eq('test@example.com')
      expect(user.name).to eq('Test User')
      expect(user.admin).to be false
    end

    it 'accepts optional attributes' do
      user = described_class.new(
        id: 1,
        email_address: 'test@example.com',
        name: 'Test User',
        admin: false,
        role_name: 'national_referee',
        created_at: Time.current,
        updated_at: Time.current
      )

      expect(user.id).to eq(1)
      expect(user.role_name).to eq('national_referee')
    end

    it 'defaults admin to false' do
      user = described_class.new(
        id: 1,
        email_address: 'test@example.com',
        name: 'Test User',
        created_at: Time.current,
        updated_at: Time.current
      )

      expect(user.admin).to be false
    end
  end

  describe '#admin?' do
    it 'returns true when admin is true' do
      user = described_class.new(
        id: 1,
        email_address: 'admin@example.com',
        name: 'Admin User',
        admin: true,
        created_at: Time.current,
        updated_at: Time.current
      )

      expect(user.admin?).to be true
    end

    it 'returns false when admin is false' do
      user = described_class.new(
        id: 1,
        email_address: 'user@example.com',
        name: 'Regular User',
        admin: false,
        created_at: Time.current,
        updated_at: Time.current
      )

      expect(user.admin?).to be false
    end
  end

  describe '#display_name' do
    it 'returns the name when present' do
      user = described_class.new(
        id: 1,
        email_address: 'john@example.com',
        name: 'John Doe',
        created_at: Time.current,
        updated_at: Time.current
      )

      expect(user.display_name).to eq('John Doe')
    end

    it 'returns email prefix when name is empty' do
      user = described_class.new(
        id: 1,
        email_address: 'john@example.com',
        name: '',
        created_at: Time.current,
        updated_at: Time.current
      )

      expect(user.display_name).to eq('john')
    end
  end

  describe 'role checking methods' do
    describe '#var_operator?' do
      it 'returns true for var_operator role' do
        user = described_class.new(
          id: 1,
          email_address: 'operator@example.com',
          name: 'Operator',
          role_name: 'var_operator',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.var_operator?).to be true
      end

      it 'returns false for other roles' do
        user = described_class.new(
          id: 1,
          email_address: 'referee@example.com',
          name: 'Referee',
          role_name: 'national_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.var_operator?).to be false
      end

      it 'returns false when role_name is nil' do
        user = described_class.new(
          id: 1,
          email_address: 'user@example.com',
          name: 'User',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.var_operator?).to be false
      end
    end

    describe '#national_referee?' do
      it 'returns true for national_referee role' do
        user = described_class.new(
          id: 1,
          email_address: 'referee@example.com',
          name: 'National Referee',
          role_name: 'national_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.national_referee?).to be true
      end

      it 'returns false for other roles' do
        user = described_class.new(
          id: 1,
          email_address: 'operator@example.com',
          name: 'Operator',
          role_name: 'var_operator',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.national_referee?).to be false
      end
    end

    describe '#international_referee?' do
      it 'returns true for international_referee role' do
        user = described_class.new(
          id: 1,
          email_address: 'intref@example.com',
          name: 'International Referee',
          role_name: 'international_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.international_referee?).to be true
      end

      it 'returns false for other roles' do
        user = described_class.new(
          id: 1,
          email_address: 'operator@example.com',
          name: 'Operator',
          role_name: 'var_operator',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.international_referee?).to be false
      end
    end

    describe '#referee?' do
      it 'returns true for national_referee' do
        user = described_class.new(
          id: 1,
          email_address: 'referee@example.com',
          name: 'Referee',
          role_name: 'national_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.referee?).to be true
      end

      it 'returns true for international_referee' do
        user = described_class.new(
          id: 2,
          email_address: 'intref@example.com',
          name: 'International Referee',
          role_name: 'international_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.referee?).to be true
      end

      it 'returns false for non-referee roles' do
        user = described_class.new(
          id: 1,
          email_address: 'operator@example.com',
          name: 'Operator',
          role_name: 'var_operator',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.referee?).to be false
      end

      it 'returns false when no role' do
        user = described_class.new(
          id: 1,
          email_address: 'user@example.com',
          name: 'User',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.referee?).to be false
      end
    end

    describe '#jury_president?' do
      it 'returns true for jury_president role' do
        user = described_class.new(
          id: 1,
          email_address: 'president@example.com',
          name: 'Jury President',
          role_name: 'jury_president',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.jury_president?).to be true
      end
    end

    describe '#referee_manager?' do
      it 'returns true for referee_manager role' do
        user = described_class.new(
          id: 1,
          email_address: 'manager@example.com',
          name: 'Referee Manager',
          role_name: 'referee_manager',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.referee_manager?).to be true
      end
    end

    describe '#broadcast_viewer?' do
      it 'returns true for broadcast_viewer role' do
        user = described_class.new(
          id: 1,
          email_address: 'viewer@example.com',
          name: 'Broadcast Viewer',
          role_name: 'broadcast_viewer',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.broadcast_viewer?).to be true
      end
    end

    describe '#has_role?' do
      it 'returns true when role matches' do
        user = described_class.new(
          id: 1,
          email_address: 'operator@example.com',
          name: 'Operator',
          role_name: 'var_operator',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.has_role?('var_operator')).to be true
        expect(user.has_role?(:var_operator)).to be true
      end

      it 'returns false when role does not match' do
        user = described_class.new(
          id: 1,
          email_address: 'operator@example.com',
          name: 'Operator',
          role_name: 'var_operator',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.has_role?('national_referee')).to be false
      end

      it 'returns false when user has no role' do
        user = described_class.new(
          id: 1,
          email_address: 'user@example.com',
          name: 'User',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.has_role?('var_operator')).to be false
      end
    end
  end

  describe 'authorization methods' do
    describe '#can_officialize_incident?' do
      it 'returns true for admin' do
        admin = described_class.new(
          id: 1,
          email_address: 'admin@example.com',
          name: 'Admin',
          admin: true,
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(admin.can_officialize_incident?).to be true
      end

      it 'returns true for national referee' do
        user = described_class.new(
          id: 2,
          email_address: 'referee@example.com',
          name: 'National Referee',
          role_name: 'national_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_officialize_incident?).to be true
      end

      it 'returns true for international referee' do
        user = described_class.new(
          id: 3,
          email_address: 'intref@example.com',
          name: 'International Referee',
          role_name: 'international_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_officialize_incident?).to be true
      end

      it 'returns true for referee manager' do
        user = described_class.new(
          id: 4,
          email_address: 'manager@example.com',
          name: 'Referee Manager',
          role_name: 'referee_manager',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_officialize_incident?).to be true
      end

      it 'returns false for var operator' do
        user = described_class.new(
          id: 5,
          email_address: 'operator@example.com',
          name: 'VAR Operator',
          role_name: 'var_operator',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_officialize_incident?).to be false
      end
    end

    describe '#can_decide_incident?' do
      it 'returns true for admin' do
        admin = described_class.new(
          id: 1,
          email_address: 'admin@example.com',
          name: 'Admin',
          admin: true,
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(admin.can_decide_incident?).to be true
      end

      it 'returns true for referee manager' do
        user = described_class.new(
          id: 2,
          email_address: 'manager@example.com',
          name: 'Referee Manager',
          role_name: 'referee_manager',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_decide_incident?).to be true
      end

      it 'returns true for international referee' do
        user = described_class.new(
          id: 3,
          email_address: 'intref@example.com',
          name: 'International Referee',
          role_name: 'international_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_decide_incident?).to be true
      end

      it 'returns false for national referee' do
        user = described_class.new(
          id: 4,
          email_address: 'referee@example.com',
          name: 'National Referee',
          role_name: 'national_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_decide_incident?).to be false
      end

      it 'returns false for var operator' do
        user = described_class.new(
          id: 5,
          email_address: 'operator@example.com',
          name: 'VAR Operator',
          role_name: 'var_operator',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_decide_incident?).to be false
      end
    end

    describe '#can_merge_incidents?' do
      it 'returns true for admin' do
        admin = described_class.new(
          id: 1,
          email_address: 'admin@example.com',
          name: 'Admin',
          admin: true,
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(admin.can_merge_incidents?).to be true
      end

      it 'returns true for referee manager' do
        user = described_class.new(
          id: 2,
          email_address: 'manager@example.com',
          name: 'Referee Manager',
          role_name: 'referee_manager',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_merge_incidents?).to be true
      end

      it 'returns false for referee' do
        user = described_class.new(
          id: 3,
          email_address: 'referee@example.com',
          name: 'National Referee',
          role_name: 'national_referee',
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_merge_incidents?).to be false
      end
    end

    describe '#can_manage_users?' do
      it 'returns true for admin' do
        admin = described_class.new(
          id: 1,
          email_address: 'admin@example.com',
          name: 'Admin',
          admin: true,
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(admin.can_manage_users?).to be true
      end

      it 'returns false for non-admin' do
        user = described_class.new(
          id: 2,
          email_address: 'user@example.com',
          name: 'Regular User',
          admin: false,
          created_at: Time.current,
          updated_at: Time.current
        )

        expect(user.can_manage_users?).to be false
      end
    end
  end

  describe 'immutability' do
    it 'cannot modify attributes after creation' do
      user = described_class.new(
        id: 1,
        email_address: 'test@example.com',
        name: 'Test User',
        admin: false,
        created_at: Time.current,
        updated_at: Time.current
      )

      expect { user.name = 'New Name' }.to raise_error(NoMethodError)
    end

    it 'creates a new instance when changing attributes' do
      user = described_class.new(
        id: 1,
        email_address: 'user@example.com',
        name: 'Test User',
        admin: false,
        created_at: Time.current,
        updated_at: Time.current
      )

      new_user = user.new(admin: true)

      expect(user.admin).to be false
      expect(new_user.admin).to be true
      expect(new_user).not_to eq(user)
    end
  end
end