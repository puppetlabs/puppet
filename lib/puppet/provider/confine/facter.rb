require 'puppet/provider/confine'

class Puppet::Provider::Confine::Facter < Puppet::Provider::Confine
    def self.summarize(confines)
        result = Hash.new { |hash, key| hash[key] = [] }
        confines.inject(result) { |total, confine| total[confine.fact] += confine.values unless confine.valid?; total }
    end

    attr_accessor :fact

    # Are we a facter comparison?
    def facter?
        defined?(@facter)
    end

    # Retrieve the value from facter
    def facter_value
        unless defined?(@facter_value) and @facter_value
            @facter_value = ::Facter.value(@fact).to_s.downcase
        end
        @facter_value
    end

    def message(value)
        "facter value '%s' for '%s' not in required list '%s'" % [value, self.fact, values.join(",")]
    end

    def pass?(value)
        facter_value == value.to_s.downcase
    end

    def reset
        # Reset the cache.  We want to cache it during a given
        # run, but across runs.
        @facter_value = nil
    end
end
