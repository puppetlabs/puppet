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
            @provider.path = file
            instances = nil
            assert_nothing_raised {
                instances = @provider.retrieve
            }

            text = @provider.fileobj.read

            dest = tempfile()
            @provider.path = dest

            # Now write it back out
            assert_nothing_raised {
                @provider.store(instances)
            }

            newtext = @provider.fileobj.read

            # Don't worry about difference in whitespace
            assert_equal(text.gsub(/\s+/, ' '), newtext.gsub(/\s+/, ' '))
        }
    end
end

# $Id$
