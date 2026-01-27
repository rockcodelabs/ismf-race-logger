# frozen_string_literal: true

module Infrastructure
  module Persistence
    class ApplicationRecord < ActiveRecord::Base
      primary_abstract_class
    end
  end
end
