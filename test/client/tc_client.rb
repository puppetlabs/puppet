if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk/"
end

require 'puppet'
require 'puppet/client'
require 'puppet/fact'
require 'test/unit'
require 'puppettest.rb'

# $Id$

class TestClient < Test::Unit::TestCase
    def test_local
        client = nil
        assert_nothing_raised() {
            client = Puppet::Client.new(:Listen => false)
        }

        facts = %w{operatingsystem operatingsystemrelease}
        facts.each { |fact|
            assert_equal(
                Puppet::Fact[fact],
                client.callfunc("fact",fact)
            )
        }
    end

    def test_files
    end
end
