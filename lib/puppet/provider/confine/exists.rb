require 'puppet/provider/confine'

class Puppet::Provider::Confine::Exists < Puppet::Provider::Confine
    def self.summarize(confines)
        confines.inject([]) { |total, confine| total + confine.summary }
    end

    def pass?(value)
        if for_binary?
            return false unless value = binary(value)
        end
        value and FileTest.exist?(value)
    end

    def message(value)
        "file %s does not exist" % value
    end

    def summary
        result.zip(values).inject([]) { |array, args| val, f = args; array << f unless val; array }
    end
end
