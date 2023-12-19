# frozen_string_literal: true

require_relative '../../../../../puppet/util/package/version/range'

module Puppet::Util::Package::Version
  class Range
    class Simple
      def initialize(version)
        @version = version
      end
    end
  end
end
