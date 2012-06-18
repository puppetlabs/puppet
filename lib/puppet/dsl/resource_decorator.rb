require 'puppet/dsl/blank_slate'

module Puppet
  module DSL
    class ResourceDecorator < BlankSlate
      attr_reader :resource

      def initialize(resource, block)
        @resource = resource
        block.call(self)
      end

      def method_missing(name, *args)
        if name =~ /\A(.*)=\z/
          @resource[$1] = args
        else
          @resource[name]
        end
      end

    end
  end
end

