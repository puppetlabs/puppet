# frozen_string_literal: true

module Puppet::Util::Package::Version
  class Gem < ::Gem::Version
    def self.parse(version)
      raise ValidationFailure, version unless version.is_a? String
      raise ValidationFailure, version unless version =~ ANCHORED_VERSION_PATTERN

      new(version)
    end

    class ValidationFailure < ArgumentError
      def initialize(version)
        super("#{version} is not a valid ruby gem version.")
      end
    end
  end
end
