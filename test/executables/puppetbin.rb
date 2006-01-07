if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

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
	include ServerTest
    def test_version
        output = nil
        assert_nothing_raised {
          output = %x{puppet --version}.chomp
        }
        assert(output == Puppet.version)
    end

    def test_execution
        file = mktestmanifest()
        @@tmpfiles << tempfile()

        output = nil
        cmd = "puppet"
        cmd += " --verbose"
        #cmd += " --fqdn %s" % fqdn
        cmd += " --confdir %s" % Puppet[:puppetconf]
        cmd += " --vardir %s" % Puppet[:puppetvar]
        cmd += " --logdest %s" % "/dev/null"

        assert_nothing_raised {
            system(cmd + " " + file)
        }
        assert($? == 0, "Puppet exited with code %s" % $?.to_i)

        assert(FileTest.exists?(@createdfile), "Failed to create config'ed file")
    end
end

# $Id: $
