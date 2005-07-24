if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $:.unshift '../../../../language/trunk/lib'
    $puppetbase = "../../../../language/trunk/"
end

require 'puppet'
require 'puppet/client'
#require 'puppet/server'
require 'puppet/fact'
require 'test/unit'
require 'puppettest.rb'

# $Id$

class TestClient < Test::Unit::TestCase
#    def test_local
#        client = nil
#        server = nil
#        assert_nothing_raised() {
#            server = Puppet::Master.new(
#                :File => file,
#                :Local => true
#            )
#        }
#        assert_nothing_raised() {
#            client = Puppet::Client.new(:Server => server)
#        }
#
#        facts = %w{operatingsystem operatingsystemrelease}
#        facts.each { |fact|
#            assert_equal(
#                Puppet::Fact[fact],
#                client.callfunc("fact",fact)
#            )
#        }
#    end

    def test_files
    end
end
