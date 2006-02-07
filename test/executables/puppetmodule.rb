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

$module = File.join($puppetbase, "ext", "module_puppet")

class TestPuppetModule < Test::Unit::TestCase
	include ExeTest

    def test_existence
        assert(FileTest.exists?($module), "Module does not exist")
    end

    def test_execution
        file = tempfile()

        createdfile = tempfile()

        File.open(file, "w") { |f|
            f.puts "class yaytest { file { \"#{createdfile}\": ensure => file } }"
        }

        output = nil
        cmd = $module
        cmd += " --verbose"
        #cmd += " --fqdn %s" % fqdn
        cmd += " --confdir %s" % Puppet[:confdir]
        cmd += " --vardir %s" % Puppet[:vardir]
        if Puppet[:debug]
            cmd += " --logdest %s" % "console"
            cmd += " --debug"
        else
            cmd += " --logdest %s" % "/dev/null"
        end

        ENV["CFALLCLASSES"] = "yaytest:all"

        assert_nothing_raised {
            system(cmd + " " + file)
        }
        assert($? == 0, "Puppet module exited with code %s" % $?.to_i)

        assert(FileTest.exists?(createdfile), "Failed to create config'ed file")
    end
end

# $Id$
