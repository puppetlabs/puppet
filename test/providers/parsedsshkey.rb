#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/fileparsing'
require 'puppet'
require 'puppet/type/sshkey'

class TestParsedSSHKey < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::FileParsing

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
