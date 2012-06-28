require 'puppet/dsl/blank_slate'

module Puppet
  module DSL
    class ResourceDecorator < BlankSlate
      attr_reader :resource

      def initialize(resource, &block)
        @resource = resource
        block[self]
      end

      def method_missing(name, *args)
        super unless respond_to? name
        if name =~ /\A(.*)=\z/
          @resource[$1.to_sym] = args.first.to_s
        else
          @resource[name]
        end
      end

      def respond_to?(name)
        name = $1.to_sym if name =~ /\A(.*)=\z/
        @resource.valid_parameter? name
      end

    end
  end
end

