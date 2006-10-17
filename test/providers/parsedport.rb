#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet'
require 'puppet/type/port'
require 'test/unit'
require 'facter'

class TestParsedPort < Test::Unit::TestCase
	include PuppetTest

    def setup
        super
        @provider = Puppet.type(:port).provider(:parsed)

        @oldfiletype = @provider.filetype
    end

    def teardown
        Puppet::FileType.filetype(:ram).clear
        @provider.filetype = @oldfiletype
        super
    end

    # Parse our sample data and make sure we regenerate it correctly.
    def test_portsparse
        fakedata("data/types/ports").each do |file|
            @provider.path = file
            instances = nil
            assert_nothing_raised {
                instances = @provider.retrieve
            }

            text = @provider.fileobj.read.gsub(/\s+/, ' ')
            text.gsub!(/ #.+$/, '')

            dest = tempfile()
            @provider.path = dest

            # Now write it back out
            assert_nothing_raised {
                @provider.store(instances)
            }

            newtext = @provider.fileobj.read.gsub(/\s+/, ' ')

            newtext.gsub!(/ #.+$/, '')

            # Don't worry about difference in whitespace
            assert_equal(text.gsub(/\s+/, ' '), newtext.gsub(/\s+/, ' '))
        end
    end
end

# $Id$
