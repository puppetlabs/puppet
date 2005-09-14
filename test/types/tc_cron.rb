if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'
require 'facter'

# $Id$

class TestExec < PuppetTest
    def test_simplecron
        
    end
end
