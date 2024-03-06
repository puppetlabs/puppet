# frozen_string_literal: true

#
# @api private
# Default Facter implementation that delegates to Facter API
#

module Puppet
  class FacterImpl
    def initialize
      require 'facter'

      setup_logging
    end

    def value(fact_name)
      ::Facter.value(fact_name)
    end

    def add(name, &block)
      ::Facter.add(name, &block)
    end

    def to_hash
      ::Facter.to_hash
    end

    def clear
      ::Facter.clear
    end

    def reset
      ::Facter.reset
    end

    def resolve(options)
      ::Facter.resolve(options)
    end

    def search_external(dirs)
      ::Facter.search_external(dirs)
    end

    def search(*dirs)
      ::Facter.search(*dirs)
    end

    def trace(value)
      ::Facter.trace(value) if ::Facter.respond_to? :trace
    end

    def debugging(value)
      ::Facter.debugging(value) if ::Facter.respond_to?(:debugging)
    end

    def load_external?
      ::Facter.respond_to?(:load_external)
    end

    def load_external(value)
      ::Facter.load_external(value) if load_external?
    end

    private

    def setup_logging
      return unless ::Facter.respond_to? :on_message

      ::Facter.on_message do |level, message|
        case level
        when :trace, :debug
          level = :debug
        when :info
          # Same as Puppet
        when :warn
          level = :warning
        when :error
          level = :err
        when :fatal
          level = :crit
        else
          next
        end

        Puppet::Util::Log.create(
          {
            :level => level,
            :source => 'Facter',
            :message => message
          }
        )
        nil
      end
    end
  end
end
