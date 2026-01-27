# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Domain
  module ValueObjects
    class BibNumber < Dry::Struct
      attribute :value, Types::BibNumber

      def to_s
        value.to_s.rjust(4, "0")
      end

      def to_i
        value
      end

      def ==(other)
        case other
        when BibNumber
          value == other.value
        when Integer
          value == other
        else
          false
        end
      end

      def <=>(other)
        case other
        when BibNumber
          value <=> other.value
        when Integer
          value <=> other
        else
          nil
        end
      end
    end
  end
end