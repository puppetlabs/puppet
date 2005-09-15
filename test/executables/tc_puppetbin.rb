if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
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

class TestPuppetBin < ServerTest
    def test_version
        output = nil
        assert_nothing_raised {
          output = %x{puppet --version}.chomp
        }
        assert(output == Puppet.version)
    end

    def test_execution
        file = mktestmanifest()
        @@tmpfiles << "/tmp/puppetbintesting"

        output = nil
        assert_nothing_raised {
            system("puppet --logdest /dev/null %s" % file)
        }
        assert($? == 0, "Puppet exited with code %s" % $?.to_i)

        assert(FileTest.exists?(@createdfile), "Failed to create config'ed file")
    end
end
