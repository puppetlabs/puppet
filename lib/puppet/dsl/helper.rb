module Puppet
  module DSL
    ##
    # Module that gathers helper functions for Ruby DSL.
    ##
    module Helper

      ##
      # This allows to access helper methods from class methods.
      ##
      def self.included(base)
        base.extend Helper
      end

      def is_ruby_dsl?(file)
        !!(file =~ /\.rb\z/)
      end

      def is_puppet_dsl?(file)
        !is_ruby_dsl? file
      end

      ##
      # Returns canonical name of a type given as an argument.
      ##
      def canonize_type(type)
        Puppet::Resource.new(type, "").type
      end

      ##
      # Returns a resource for the passed reference
      ##
      def get_resource(reference)
        case reference
        when ::Puppet::Resource
          reference
        when ::Puppet::DSL::ResourceReference
          reference.resource
        when ::String
          ::Puppet::DSL::Parser.current_scope.findresource reference
        else
          nil
        end
      end

      ##
      # Removes unnecessary noise from backtraces and reraises catched exception
      ##
      def silence_backtrace
        yield
      rescue Exception => e
        backtrace = e.backtrace.reject {|l| l =~ %r|lib/puppet| or l =~ %r|bin/puppet| }
        e.set_backtrace backtrace

        raise e
      end

    end
  end
end


