module Puppet
  module DSL
    ##
    # Module that gathers helper functions for Ruby DSL.
    ##
    module Helper
      def is_ruby_filename?(file)
        !!(file =~ /\.rb\z/i)
      end

      def is_puppet_filename?(file)
        !!(file =~ /\.pp\z/i)
      end

      ##
      # Returns canonical name of a type given as an argument.
      ##
      def canonicalize_type(type)
        Puppet::Resource.new(type, "").type
      end

    end
  end
end


