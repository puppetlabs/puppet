# frozen_string_literal: true

require_relative '../../../../../puppet/util/package/version/range'

module Puppet::Util::Package::Version
  class Range
    class MinMax
      def initialize(min, max)
        @min = min
        @max = max
      end

      def to_s
        "#{@min} #{@max}"
      end

      def to_gem_version
        "#{@min}, #{@max}"
      end

      def include?(version)
        @min.include?(version) && @max.include?(version)
      end
    end
  end
end
