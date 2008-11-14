# Manage a collection of confines, returning a boolean or
# helpful information.
require 'puppet/provider/confine'

class Puppet::Provider::ConfineCollection
    def confine(hash)
        if hash.include?(:for_binary)
            for_binary = true
            hash.delete(:for_binary)
        else
            for_binary = false
        end
        hash.each do |test, values|
            if klass = Puppet::Provider::Confine.test(test)
                @confines << klass.new(values)
                @confines[-1].for_binary = true if for_binary
            else
                confine = Puppet::Provider::Confine.test(:variable).new(values)
                confine.name = test
                @confines << confine
            end
            @confines[-1].label = self.label
        end
    end

    attr_reader :label
    def initialize(label)
        @label = label
        @confines = []
    end

    # Return a hash of the whole confine set, used for the Provider
    # reference.
    def summary
        confines = Hash.new { |hash, key| hash[key] = [] }
        @confines.each { |confine| confines[confine.class] << confine }
        result = {}
        confines.each do |klass, list|
            value = klass.summarize(list)
            next if (value.respond_to?(:length) and value.length == 0) or (value == 0)
            result[klass.name] = value

        end
        result
    end

    def valid?
        ! @confines.detect { |c| ! c.valid? }
    end
end
