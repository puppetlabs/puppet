require 'puppet/provider/confine'

class Puppet::Provider::Confine::Variable < Puppet::Provider::Confine
    def self.summarize(confines)
        result = Hash.new { |hash, key| hash[key] = [] }
        confines.inject(result) { |total, confine| total[confine.fact] += confine.values unless confine.valid?; total }
    end

    attr_accessor :name

    # Retrieve the value from facter
    def facter_value
        unless defined?(@facter_value) and @facter_value
            @facter_value = ::Facter.value(name).to_s.downcase
        end
        @facter_value
    end

    def message(value)
        "facter value '%s' for '%s' not in required list '%s'" % [value, self.name, values.join(",")]
    end

    def pass?(value)
        test_value.downcase.to_s == value.to_s.downcase
    end

    def reset
        # Reset the cache.  We want to cache it during a given
        # run, but across runs.
        @facter_value = nil
    end

    private

    def setting?
        Puppet.settings.valid?(name)
    end

    def test_value
        setting? ? Puppet.settings[name] : facter_value 
    end
end
