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
            @confines << Puppet::Provider::Confine.new(test, values)
            @confines[-1].for_binary = true if for_binary
        end
    end

    def initialize
        @confines = []
    end

    # Return a hash of the whole confine set, used for the Provider
    # reference.
    def result
        defaults = {
            :false => 0,
            :true => 0,
            :exists => [],
            :facter => {}
        }
        missing = Hash.new { |hash, key| hash[key] = defaults[key] }
        @confines.each do |confine|
            case confine.test
            when :false: missing[confine.test] += confine.result.find_all { |v| v == false }.length
            when :true: missing[confine.test] += confine.result.find_all { |v| v == true }.length
            when :exists: confine.result.zip(confine.values).each { |val, f| missing[:exists] << f unless val }
            when :facter: missing[:facter][confine.fact] = confine.values if confine.result.include?(false)
            end
        end

        missing
    end

    def valid?
        ! @confines.detect { |c| ! c.valid? }
    end
end
