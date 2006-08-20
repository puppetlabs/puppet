if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestError < Test::Unit::TestCase
    include TestPuppet

    def test_errorisstring
        error = nil
        assert_nothing_raised {
            error = Puppet::ParseError.new("This is an error")
        }
        assert_instance_of(String, error.to_s)
    end
end

# $Id$
