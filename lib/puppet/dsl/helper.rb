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
      # Checks whether resource type exists
      ##
      def is_resource_type?(name)
        type = canonize_type(name)
        !!(["Node", "Class"].include? type or
           ::Puppet::Type.type type or
           ::Puppet::DSL::Parser.current_scope.known_resource_types.find_definition '', type or
           ::Puppet::DSL::Parser.current_scope.known_resource_types.find_hostclass  '', type)
      end

      ##
      # Checks whether Puppet function exists
      ##
      def is_function?(name)
        !!::Puppet::Parser::Functions.function(name)
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
        exception = Puppet::Error.new e.message
        exception.set_backtrace backtrace

        raise exception
      end

    end
  end
end


