# frozen_string_literal: true

require "rails_helper"

RSpec.describe DB::Repo do
  # Create a test repo class for testing the base class behavior
  let(:test_repo_class) do
    Class.new(described_class) do
      self.record_class = User
      self.struct_class = Structs::User
      self.summary_class = Structs::UserSummary

      returns_one :find, :find!, :custom_find
      returns_many :all, :custom_list

      def custom_find(email)
        record = base_scope.find_by(email_address: email)
        to_struct(record)
      end

      def custom_list
        base_scope.limit(2).map { |record| to_summary(record) }
      end

      protected

      def base_scope
        User.includes(:role).order(created_at: :desc)
      end

      def build_struct(record)
        Structs::User.new(
          id: record.id,
          email_address: record.email_address,
          name: record.name,
          admin: record.admin,
          role_name: record.role&.name,
          created_at: record.created_at,
          updated_at: record.updated_at
        )
      end

      def build_summary(record)
        Structs::UserSummary.new(
          id: record.id,
          email_address: record.email_address,
          name: record.name,
          admin: record.admin,
          role_name: record.role&.name
        )
      end
    end
  end

  subject(:repo) { test_repo_class.new }

  describe "class configuration" do
    it "stores record_class" do
      expect(test_repo_class.record_class).to eq(User)
    end

    it "stores struct_class" do
      expect(test_repo_class.struct_class).to eq(Structs::User)
    end

    it "stores summary_class" do
      expect(test_repo_class.summary_class).to eq(Structs::UserSummary)
    end
  end

  describe ".returns_one" do
    it "records methods that return single structs" do
      expect(test_repo_class.one_methods).to include(:find, :find!, :custom_find)
    end
  end

  describe ".returns_many" do
    it "records methods that return collections" do
      expect(test_repo_class.many_methods).to include(:all, :custom_list)
    end
  end

  describe "#find" do
    context "when record exists" do
      let!(:user) { create(:user, name: "Test User") }

      it "returns a full struct" do
        result = repo.find(user.id)

        expect(result).to be_a(Structs::User)
        expect(result.id).to eq(user.id)
        expect(result.name).to eq("Test User")
      end
    end

    context "when record does not exist" do
      it "returns nil" do
        result = repo.find(999999)

        expect(result).to be_nil
      end
    end
  end

  describe "#find!" do
    context "when record exists" do
      let!(:user) { create(:user) }

      it "returns a full struct" do
        result = repo.find!(user.id)

        expect(result).to be_a(Structs::User)
        expect(result.id).to eq(user.id)
      end
    end

    context "when record does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { repo.find!(999999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#first" do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }

    it "returns the first record as a struct (based on base_scope ordering)" do
      result = repo.first

      expect(result).to be_a(Structs::User)
      # base_scope orders by created_at desc, so user2 is first
      expect(result.id).to eq(user2.id)
    end

    context "when no records exist" do
      before { User.destroy_all }

      it "returns nil" do
        expect(repo.first).to be_nil
      end
    end
  end

  describe "#last" do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }

    it "returns the last record as a struct (based on base_scope ordering)" do
      result = repo.last

      expect(result).to be_a(Structs::User)
      # base_scope orders by created_at desc, so user1 is last
      expect(result.id).to eq(user1.id)
    end
  end

  describe "#find_by" do
    let!(:user) { create(:user, email_address: "findby@example.com") }

    it "finds by arbitrary conditions" do
      result = repo.find_by(email_address: "findby@example.com")

      expect(result).to be_a(Structs::User)
      expect(result.email_address).to eq("findby@example.com")
    end

    it "returns nil when not found" do
      result = repo.find_by(email_address: "notfound@example.com")

      expect(result).to be_nil
    end
  end

  describe "#all" do
    let!(:users) { create_list(:user, 3) }

    it "returns all records as summary structs" do
      result = repo.all

      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
      expect(result).to all(be_a(Structs::UserSummary))
    end

    it "orders by base_scope (created_at desc)" do
      result = repo.all

      expect(result.map(&:id)).to eq(users.reverse.map(&:id))
    end
  end

  describe "#where" do
    let!(:admin1) { create(:user, admin: true) }
    let!(:admin2) { create(:user, admin: true) }
    let!(:regular) { create(:user, admin: false) }

    it "returns matching records as summary structs" do
      result = repo.where(admin: true)

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::UserSummary))
      expect(result.map(&:id)).to contain_exactly(admin1.id, admin2.id)
    end

    it "returns empty array when no matches" do
      result = repo.where(email_address: "nonexistent@example.com")

      expect(result).to eq([])
    end
  end

  describe "#many" do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:user3) { create(:user) }

    it "returns records for given IDs as summary structs" do
      result = repo.many([ user1.id, user3.id ])

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::UserSummary))
      expect(result.map(&:id)).to contain_exactly(user1.id, user3.id)
    end

    it "returns empty array for non-existent IDs" do
      result = repo.many([ 999998, 999999 ])

      expect(result).to eq([])
    end
  end

  describe "#count" do
    before { create_list(:user, 5) }

    it "returns the total count" do
      expect(repo.count).to eq(5)
    end
  end

  describe "#exists?" do
    let!(:user) { create(:user, email_address: "exists@example.com") }

    it "returns true when matching record exists" do
      expect(repo.exists?(email_address: "exists@example.com")).to be true
    end

    it "returns false when no matching record" do
      expect(repo.exists?(email_address: "notexists@example.com")).to be false
    end
  end

  describe "#pluck" do
    let!(:user1) { create(:user, name: "Alice") }
    let!(:user2) { create(:user, name: "Bob") }

    it "returns array of values for single column" do
      result = repo.pluck(:name)

      expect(result).to contain_exactly("Alice", "Bob")
    end

    it "returns array of arrays for multiple columns" do
      result = repo.pluck(:id, :name)

      expect(result).to contain_exactly([ user1.id, "Alice" ], [ user2.id, "Bob" ])
    end
  end

  describe "#create" do
    let(:valid_attrs) do
      {
        email_address: "created@example.com",
        name: "Created User",
        password: "password123",
        password_confirmation: "password123",
        admin: false
      }
    end

    it "creates a record and returns a full struct" do
      result = repo.create(valid_attrs)

      expect(result).to be_a(Structs::User)
      expect(result.email_address).to eq("created@example.com")
      expect(result.name).to eq("Created User")
      expect(User.exists?(email_address: "created@example.com")).to be true
    end

    it "returns nil on validation failure" do
      # Missing required password
      result = repo.create(email_address: "invalid@example.com", name: "Invalid")

      expect(result).to be_nil
    end
  end

  describe "#update" do
    let!(:user) { create(:user, name: "Original Name") }

    it "updates the record and returns a full struct" do
      result = repo.update(user.id, name: "Updated Name")

      expect(result).to be_a(Structs::User)
      expect(result.name).to eq("Updated Name")
      expect(user.reload.name).to eq("Updated Name")
    end

    it "returns nil when record not found" do
      result = repo.update(999999, name: "Test")

      expect(result).to be_nil
    end
  end

  describe "#delete" do
    let!(:user) { create(:user) }

    it "deletes the record and returns true" do
      result = repo.delete(user.id)

      expect(result).to be true
      expect(User.exists?(user.id)).to be false
    end

    it "returns nil when record not found" do
      result = repo.delete(999999)

      expect(result).to be_nil
    end
  end

  describe "custom methods" do
    describe "#custom_find" do
      let!(:user) { create(:user, email_address: "custom@example.com") }

      it "uses to_struct to return a full struct" do
        result = repo.custom_find("custom@example.com")

        expect(result).to be_a(Structs::User)
        expect(result.email_address).to eq("custom@example.com")
      end
    end

    describe "#custom_list" do
      before { create_list(:user, 5) }

      it "uses to_summary to return summary structs" do
        result = repo.custom_list

        expect(result).to be_an(Array)
        expect(result.size).to eq(2)  # limited to 2
        expect(result).to all(be_a(Structs::UserSummary))
      end
    end
  end

  describe "subclass without build_struct implementation" do
    let(:incomplete_repo_class) do
      Class.new(described_class) do
        self.record_class = User
      end
    end

    it "raises NotImplementedError" do
      user = create(:user)
      repo = incomplete_repo_class.new

      expect { repo.find(user.id) }.to raise_error(NotImplementedError)
    end
  end

  describe "subclass without build_summary implementation" do
    let(:incomplete_repo_class) do
      Class.new(described_class) do
        self.record_class = User

        protected

        def build_struct(record)
          Structs::User.new(
            id: record.id,
            email_address: record.email_address,
            name: record.name,
            admin: record.admin,
            role_name: nil,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end

    it "raises NotImplementedError when calling all" do
      create(:user)
      repo = incomplete_repo_class.new

      expect { repo.all }.to raise_error(NotImplementedError)
    end
  end
end
