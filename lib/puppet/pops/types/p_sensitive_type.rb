# frozen_string_literal: true

module Puppet::Pops
module Types
# A Puppet Language type that wraps sensitive information. The sensitive type is parameterized by
# the wrapped value type.
#
#
# @api public
class PSensitiveType < PTypeWithContainedType
  class Sensitive
    def initialize(value)
      @value = value
    end

    def unwrap
      @value
    end

    def to_s
      "Sensitive [value redacted]"
    end

    def inspect
      "#<#{self}>"
    end

    def hash
      @value.hash
    end

    def ==(other)
      other.is_a?(Sensitive) &&
        other.hash == hash
    end
    alias eql? ==
  end

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType')
  end

  def initialize(type = nil)
    @type = type.nil? ? PAnyType.new : type.generalize
  end

  def instance?(o, guard = nil)
    o.is_a?(Sensitive) && @type.instance?(o.unwrap, guard)
  end

  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_Sensitive, type.loader) do
      dispatch :from_sensitive do
        param 'Sensitive', :value
      end

      dispatch :from_any do
        param 'Any', :value
      end

      def from_any(value)
        Sensitive.new(value)
      end

      # Since the Sensitive value is immutable we can reuse the existing instance instead of making a copy.
      def from_sensitive(value)
        value
      end
    end
  end

  private

  def _assignable?(o, guard)
    instance_of?(o.class) && @type.assignable?(o.type, guard)
  end

  DEFAULT = PSensitiveType.new
end
end
end
