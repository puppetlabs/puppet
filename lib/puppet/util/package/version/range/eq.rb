# frozen_string_literal: true

require_relative '../../../../../puppet/util/package/version/range/simple'

module Puppet::Util::Package::Version
  class Range
    class Eq < Simple
      def to_s
        @version.to_s
      end

      def include?(version)
        version == @version
      end
    end
  end
end
