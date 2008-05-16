# The class that handles testing whether our providers
# actually work or not.
require 'puppet/util'

class Puppet::Provider::Confine
    include Puppet::Util

    attr_reader :test, :values, :fact

    # Mark that this confine is used for testing binary existence.
    attr_accessor :for_binary
    def for_binary?
        for_binary
    end

    def exists?(value)
        if for_binary?
            return false unless value = binary(value)
        end
        value and FileTest.exist?(value)
    end

    # Are we a facter comparison?
    def facter?
        defined?(@facter)
    end

    # Retrieve the value from facter
    def facter_value
        unless defined?(@facter_value) and @facter_value
            @facter_value = Facter.value(@fact).to_s.downcase
        end
        @facter_value
    end

    def false?(value)
        ! value
    end

    def initialize(test, values)
        values = [values] unless values.is_a?(Array)
        @values = values

        if %w{exists false true}.include?(test.to_s)
            @test = test
            @method = @test.to_s + "?"
        else
            @fact = test
            @test = :facter
            @method = "match?"
        end
    end

    def match?(value)
        facter_value == value.to_s.downcase
    end

    # Collect the results of all of them.
    def result
        values.collect { |value| send(@method, value) }
    end

    def true?(value)
        # Double negate, so we only get true or false.
        ! ! value
    end

    # Test whether our confine matches.
    def valid?
        values.each do |value|
            unless send(@method, value)
                msg = case test
                      when :false:  "false value when expecting true"
                      when :true:  "true value when expecting false"
                      when :exists:  "file %s does not exist" % value
                      when :facter:  "facter value '%s' for '%s' not in required list '%s'" % [value, @fact, values.join(",")]
                      end
                Puppet.debug msg
                return false
            end
        end

        return true
    ensure
        # Reset the cache.  We want to cache it during a given
        # run, but across runs.
        @facter_value = nil
    end
end
