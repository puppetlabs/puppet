require 'puppet'
require 'puppet/server'
require 'puppet/sslcertificates'
require 'puppettest'

class TestPuppetModule < Test::Unit::TestCase
    include PuppetTest::ExeTest


    def setup
        super
        @module = File.join(basedir, "ext", "module_puppet")
    end

    def test_existence
        assert(FileTest.exists?(@module), "Module does not exist")
    end

    def test_execution
        file = tempfile()

        createdfile = tempfile()

        File.open(file, "w") { |f|
            f.puts "class yaytest { file { \"#{createdfile}\": ensure => file } }"
        }

        output = nil
        cmd = @module
        cmd += " --verbose"
        #cmd += " --fqdn %s" % fqdn
        cmd += " --confdir %s" % Puppet[:confdir]
        cmd += " --vardir %s" % Puppet[:vardir]
        if Puppet[:debug]
            cmd += " --logdest %s" % "console"
            cmd += " --debug"
            cmd += " --trace"
        else
            cmd += " --logdest %s" % "/dev/null"
        end

        ENV["CFALLCLASSES"] = "yaytest:all"
        libsetup

        out = nil
        assert_nothing_raised {
            out = %x{#{cmd + " " + file} 2>&1}
        }
        assert($? == 0, "Puppet module exited with code %s: %s" % [$?.to_i, out])

        assert(FileTest.exists?(createdfile), "Failed to create config'ed file")
    end
end

# $Id$
