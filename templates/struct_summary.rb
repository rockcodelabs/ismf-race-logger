# frozen_string_literal: true

module Structs
  # Lightweight struct for {{Resource}} collections (performance optimized)
  #
  # Use Ruby Data.define for collections to achieve ~7x faster instantiation
  # compared to dry-struct. Keep minimal fields needed for list/index views.
  #
  # @example
  #   summary = Structs::{{Resource}}Summary.new(id: 1, name: "Example", status: "active")
  #   summary.active? # => true
  #
  {{Resource}}Summary = Data.define(:id, :name, :status) do
    # Domain methods only (no presentation logic)

    def active?
      status == "active"
    end
  end
end