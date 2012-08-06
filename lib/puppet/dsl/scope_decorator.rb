module Puppet
  module DSL
    class ScopeDecorator

      def initialize(scope)
        raise ArgumentError, "no scope set" unless scope
        @scope = scope
      end

      def [](key)
        @scope[key.to_s]
      end

      def []=(key, value)
        @scope[key.to_s] = value
      end

    end
  end
end

