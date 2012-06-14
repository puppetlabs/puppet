require 'puppet/dsl/blank_slate'

module Puppet
  module DSL
    class Container < BlankSlate

      def initialize(code)
        @attributes = Hash.new { |h, k| h[k] = [] }
        @code = code
      end

      def method_missing(name, *args)
        if name =~ /(.*)=/
          @attributes[$1] = []
          @attributes[$1] << args.first
        else
          @attributes[key]
        end
      end

      def to_hash
        instance_eval &@code
        @attributes
      end

    end
  end
end

