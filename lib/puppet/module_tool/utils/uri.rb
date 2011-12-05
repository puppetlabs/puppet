require 'uri'

module Puppet::Module::Tool
  module Utils
    module URI

      # Return a URI instance for the +uri+, a a string or URI object.
      def normalize(url)
        return url.is_a?(::URI) ?
          url :
          ::URI.parse(url)
      end
    end
  end
end
