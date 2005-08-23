if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '../../../../library/trunk/lib/'
    $:.unshift '../../../../library/trunk/test/'
    $puppetbase = "../.."
end

# $ID: $

require 'puppet'
require 'puppet/server'
require 'puppet/sslcertificates'
require 'test/unit'
require 'puppettest.rb'

# add the bin directory to our search path
ENV["PATH"] += ":" + File.join($puppetbase, "bin")

# and then the library directories
libdirs = $:.find_all { |dir|
    dir =~ /puppet/ or dir =~ /\.\./
}
ENV["RUBYLIB"] = libdirs.join(":")

class TestPuppetBin < Test::Unit::TestCase
    def setup
    end

    def teardown
    end

    def test_version
        output = nil
        assert_nothing_raised {
          output = %x{puppet --version}.chomp
        }
        assert(output == Puppet.version)
    end
end
