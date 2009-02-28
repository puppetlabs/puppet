#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppettest'

class TestPuppetBin < Test::Unit::TestCase
    include PuppetTest::ExeTest
    def test_version
        output = nil
        assert_nothing_raised {
          output = %x{puppet --version}.chomp
        }
        assert_equal(Puppet.version, output)
    end

    def test_execution
        file = mktestmanifest()

        output = nil
        cmd = "puppet"
        if Puppet[:debug]
            cmd += " --debug"
        end
        cmd += " --confdir %s" % Puppet[:confdir]
        cmd += " --vardir %s" % Puppet[:vardir]
        unless Puppet[:debug]
            cmd += " --logdest %s" % "/dev/null"
        end

        assert_nothing_raised {
            output = %x{#{cmd + " " + file} 2>&1}
        }
        assert($? == 0, "Puppet exited with code %s" % $?.to_i)

        assert(FileTest.exists?(@createdfile), "Failed to create config'ed file")
    end

    def test_inlineexecution
        path = tempfile()
        code = "file { '#{path}': ensure => file }"

        output = nil
        cmd = "puppet"
        if Puppet[:debug]
            cmd += " --debug"
        end
        #cmd += " --fqdn %s" % fqdn
        cmd += " --confdir %s" % Puppet[:confdir]
        cmd += " --vardir %s" % Puppet[:vardir]
        unless Puppet[:debug]
            cmd += " --logdest %s" % "/dev/null"
        end

        cmd += " -e \"#{code}\""

        assert_nothing_raised {
            out = %x{#{cmd} 2>&1}
        }
        assert($? == 0, "Puppet exited with code %s" % $?.to_i)

        assert(FileTest.exists?(path), "Failed to create config'ed file")
    end

    def test_stdin_execution
        path = tempfile()
        manifest = tempfile()
        env = %x{which env}.chomp
        if env == ""
            Puppet.info "cannot find env; cannot test stdin_execution"
            return
        end
        File.open(manifest, "w") do |f|
            f.puts "#!#{env} puppet
            exec { '/bin/touch #{path}': }"
        end
        File.chmod(0755, manifest)

        assert_nothing_raised {
            out = %x{#{manifest} 2>&1}
        }
        assert($? == 0, "manifest exited with code %s" % $?.to_i)

        assert(FileTest.exists?(path), "Failed to create config'ed file")
    end

    def test_parseonly
        path = tempfile()
        manifest = tempfile()
        puppet = %x{which puppet}.chomp
        if puppet == ""
            Puppet.info "cannot find puppet; cannot test parseonly"
            return
        end
        code = 'File <<| |>>
        include nosuchclass'

        assert_nothing_raised {
            IO.popen("#{puppet} --parseonly", 'w') { |p| p.puts code }
        }
        assert($? == 0, "parseonly test exited with code %s" % $?.to_i)
    end
end

