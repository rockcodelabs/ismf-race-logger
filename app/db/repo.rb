# frozen_string_literal: true

module DB
  # Base class for all repositories
  #
  # Repositories are the public interface for data access.
  # They return structs (immutable data objects), not ActiveRecord models.
  #
  # Key conventions:
  # - Single record methods return full structs (dry-struct) or nil
  # - Collection methods return summary structs (Ruby Data) for performance
  # - Aggregate methods (count, exists?, pluck) return raw values
  # - CRUD operations return full structs
  #
  # Example:
  #   class UserRepo < DB::Repo
  #     self.record_class = User
  #     self.struct_class = Structs::User
  #     self.summary_class = Structs::UserSummary
  #
  #     returns_one :find, :find!, :find_by_email, :authenticate
  #     returns_many :all, :admins, :referees
  #
  #     def find_by_email(email)
  #       record = base_scope.find_by(email_address: email)
  #       to_struct(record)
  #     end
  #
  #     protected
  #
  #     def build_struct(record)
  #       struct_class.new(
  #         id: record.id,
  #         email_address: record.email_address,
  #         # ...
  #       )
  #     end
  #   end
  #
  class Repo
    class << self
      attr_accessor :record_class, :struct_class, :summary_class

      # Declare which methods return a single (full) struct
      # This is documentation/intention and can be used for validation
      def returns_one(*methods)
        @one_methods ||= []
        @one_methods.concat(methods)
      end

      # Declare which methods return a collection of summary structs
      def returns_many(*methods)
        @many_methods ||= []
        @many_methods.concat(methods)
      end

      def one_methods
        @one_methods || []
      end

      def many_methods
        @many_methods || []
      end
    end

    #==========================================================================
    # SINGLE RECORD METHODS → Return full struct (or nil)
    #==========================================================================

    # Find a record by ID, returns struct or nil
    def find(id)
      record = base_scope.find_by(id: id)
      to_struct(record)
    end

    # Find a record by ID, raises ActiveRecord::RecordNotFound if not found
    def find!(id)
      record = base_scope.find(id)
      to_struct(record)
    end

    # Find the first record
    def first
      to_struct(base_scope.first)
    end

    # Find the last record
    def last
      to_struct(base_scope.last)
    end

    # Find a record by conditions, returns struct or nil
    def find_by(**conditions)
      record = base_scope.find_by(**conditions)
      to_struct(record)
    end

    #==========================================================================
    # COLLECTION METHODS → Return summary structs (for performance)
    #==========================================================================

    # Return all records as summary structs
    def all
      base_scope.map { |record| to_summary(record) }
    end

    # Return records matching conditions as summary structs
    def where(**conditions)
      base_scope.where(**conditions).map { |record| to_summary(record) }
    end

    # Return records for given IDs as summary structs
    def many(ids)
      base_scope.where(id: ids).map { |record| to_summary(record) }
    end

    #==========================================================================
    # AGGREGATE METHODS → Return raw values
    #==========================================================================

    def count
      record_class.count
    end

    def exists?(**conditions)
      record_class.exists?(**conditions)
    end

    def pluck(*columns)
      record_class.pluck(*columns)
    end

    #==========================================================================
    # CRUD OPERATIONS → Return full struct
    #==========================================================================

    # Create a new record, returns struct or nil on validation failure
    def create(attrs)
      record = record_class.create!(attrs)
      to_struct(record)
    rescue ActiveRecord::RecordInvalid
      nil
    end

    # Update a record by ID, returns struct or nil on failure
    def update(id, attrs)
      record = record_class.find(id)
      record.update!(attrs)
      to_struct(record)
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
      nil
    end

    # Delete a record by ID, returns true or nil if not found
    def delete(id)
      record_class.find(id).destroy
      true
    rescue ActiveRecord::RecordNotFound
      nil
    end

    #==========================================================================
    # PROTECTED: Override in subclasses
    #==========================================================================

    protected

    # Access class-level configuration
    def record_class
      self.class.record_class
    end

    def struct_class
      self.class.struct_class
    end

    def summary_class
      self.class.summary_class
    end

    # Override to add default scopes (e.g., includes, order)
    # This prevents N+1 queries when eager-loading associations
    def base_scope
      record_class.all
    end

    # Convert a record to a full struct
    def to_struct(record)
      return nil unless record

      build_struct(record)
    end

    # Convert a record to a summary struct
    def to_summary(record)
      return nil unless record

      build_summary(record)
    end

    # Build a full struct from a record
    # Override in subclass to map record attributes to struct
    def build_struct(record)
      raise NotImplementedError, "#{self.class} must implement #build_struct"
    end

    # Build a summary struct from a record
    # Override in subclass to map record attributes to summary
    def build_summary(record)
      raise NotImplementedError, "#{self.class} must implement #build_summary"
    end
  end
end