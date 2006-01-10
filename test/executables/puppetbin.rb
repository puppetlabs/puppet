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

class TestPuppetBin < Test::Unit::TestCase
	include ExeTest
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
        if Puppet[:debug]
            cmd += " --debug"
        end
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
