module Puppet
  module Util

    ##
    # Module that gathers helper functions for determining type of manifests.
    ##
    module ManifestFiletypeHelper
      extend self

      def is_ruby_filename?(file)
        !!(file =~ /\.rb\z/i)
      end

      def is_puppet_filename?(file)
        !!(file =~ /\.pp\z/i)
      end

    end
  end
end


