# Test key job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'puppet/type/parsedtype/sshkey'
require 'test/unit'
require 'facter'

class TestParsedSSHKey < Test::Unit::TestCase
	include TestPuppet

    def setup
        super
        @provider = Puppet.type(:sshkey).provider(:parsed)

        @oldfiletype = @provider.filetype
    end

    def teardown
        Puppet::FileType.filetype(:ram).clear
        @provider.filetype = @oldfiletype
        super
    end

    def test_keysparse
        fakedata("data/types/sshkey").each { |file|
            fakedataparse(file)
        }
    end
end

# $Id$
