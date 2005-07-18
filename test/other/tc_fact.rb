if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk/"
end

require 'puppet/fact'
require 'facter'
require 'test/unit'

# $Id$

class TestFacts < Test::Unit::TestCase
    def test_newfact
        Puppet[:debug] = true if __FILE__ == $0
        fact = nil
        assert_nothing_raised() {
            fact = Puppet::Fact.new(
                :name => "funtest",
                :code => "echo funtest",
                :interpreter => "/bin/sh"
            )
        }
        assert_equal(
            "funtest",
            Puppet::Fact["funtest"]
        )
    end

    def test_os
        assert_equal(Facter["operatingsystem"].value,
            Puppet::Fact["operatingsystem"]
        )
    end
end
