# frozen_string_literal: true

require "dry/monads"

module Infrastructure
  module Persistence
    module Repositories
      class UserRepository
        include Dry::Monads[:result]

        def find(id)
          record = Records::UserRecord.find_by(id: id)
          return Failure(:not_found) unless record

          Success(to_entity(record))
        end

        def find_by_email(email_address)
          record = Records::UserRecord.find_by(email_address: email_address)
          return Failure(:not_found) unless record

          Success(to_entity(record))
        end

        def authenticate(email_address, password)
          record = Records::UserRecord.authenticate_by(
            email_address: email_address,
            password: password
          )

          return Failure(:invalid_credentials) unless record

          Success(to_entity(record))
        end

        def create(attributes)
          role_record = nil
          if attributes[:role_name]
            role_record = Records::RoleRecord.find_by(name: attributes[:role_name])
            return Failure([ :role_not_found, attributes[:role_name] ]) unless role_record
          end

          record = Records::UserRecord.new(
            email_address: attributes[:email_address],
            name: attributes[:name],
            password: attributes[:password],
            password_confirmation: attributes[:password_confirmation],
            admin: attributes.fetch(:admin, false),
            role_id: role_record&.id
          )

          if record.save
            Success(to_entity(record))
          else
            Failure([ :validation_failed, record.errors.to_hash ])
          end
        end

        def update(id, attributes)
          record = Records::UserRecord.find(id)

          # Handle role change if provided
          if attributes[:role_name]
            role_record = Records::RoleRecord.find_by(name: attributes[:role_name])
            return Failure([ :role_not_found, attributes[:role_name] ]) unless role_record
            attributes[:role_id] = role_record.id
            attributes.delete(:role_name)
          end

          if record.update(attributes)
            Success(to_entity(record))
          else
            Failure([ :validation_failed, record.errors.to_hash ])
          end
        rescue ActiveRecord::RecordNotFound
          Failure(:not_found)
        end

        def delete(id)
          record = Records::UserRecord.find(id)
          record.destroy
          Success(true)
        rescue ActiveRecord::RecordNotFound
          Failure(:not_found)
        end

        def all
          records = Records::UserRecord.ordered.to_a
          Success(records.map { |r| to_entity(r) })
        end

        def admins
          records = Records::UserRecord.admins.ordered.to_a
          Success(records.map { |r| to_entity(r) })
        end

        def referees
          records = Records::UserRecord.referees.ordered.to_a
          Success(records.map { |r| to_entity(r) })
        end

        def with_role(role_name)
          records = Records::UserRecord.with_role(role_name).ordered.to_a
          Success(records.map { |r| to_entity(r) })
        end

        def exists?(email_address)
          Records::UserRecord.exists?(email_address: email_address)
        end

        private

        def to_entity(record)
          Domain::Entities::User.new(
            id: record.id,
            email_address: record.email_address,
            name: record.name,
            admin: record.admin || false,
            role_name: record.role_record&.name,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
