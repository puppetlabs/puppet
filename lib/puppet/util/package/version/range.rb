# frozen_string_literal: true

require_relative 'range/lt'
require_relative 'range/lt_eq'
require_relative 'range/gt'
require_relative 'range/gt_eq'
require_relative 'range/eq'
require_relative 'range/min_max'

module Puppet::Util::Package::Version
  class Range
    class ValidationFailure < ArgumentError; end
    # Parses a version range string into a comparable {Range} instance.
    #
    # Currently parsed version range string may take any of the following
    # forms:
    #
    # * Regular Version strings
    #   * ex. `"1.0.0"`, `"1.2.3-pre"`
    # * Inequalities
    #   * ex. `">1.0.0"`, `"<3.2.0"`, `">=4.0.0"`
    # * Range Intersections (min is always first)
    #   * ex. `">1.0.0 <=2.3.0"`
    #
    RANGE_SPLIT = /\s+/
    FULL_REGEX = /\A((?:[<>=])*)(.+)\Z/

    # @param range_string [String] the version range string to parse
    # @param version_class [Version] a version class implementing comparison operators and parse method
    # @return [Range] a new {Range} instance
    # @api public
    def self.parse(range_string, version_class)
      raise ValidationFailure, "Unable to parse '#{range_string}' as a string" unless range_string.is_a?(String)

      simples = range_string.split(RANGE_SPLIT).map do |simple|
        match, operator, version = *simple.match(FULL_REGEX)
        raise ValidationFailure, "Unable to parse '#{simple}' as a version range identifier" unless match

        case operator
        when '>'
          Gt.new(version_class.parse(version))
        when '>='
          GtEq.new(version_class.parse(version))
        when '<'
          Lt.new(version_class.parse(version))
        when '<='
          LtEq.new(version_class.parse(version))
        when ''
          Eq.new(version_class.parse(version))
        else
          raise ValidationFailure, "Operator '#{operator}' is not implemented"
        end
      end
      simples.size == 1 ? simples[0] : MinMax.new(simples[0], simples[1])
    end
  end
end
