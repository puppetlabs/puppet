require 'puppet/util/package/version/range/simple'

module Puppet::Util::Package::Version
  class Range
    class GtEq < Simple
      def to_s
        ">=#{@version}"
      end
      def include?(version)
        version >= @version
      end
    end
  end
end
