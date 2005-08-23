if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '../../../../library/trunk/lib/'
    $:.unshift '../../../../library/trunk/test/'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/server'
require 'puppet/sslcertificates'
require 'test/unit'
require 'puppettest.rb'

# $Id$

# ok, we have to add the bin directory to our search path
ENV["PATH"] += ":" + File.join($puppetbase, "bin")

# and then the library directories
libdirs = $:.find_all { |dir|
    dir =~ /puppet/ or dir =~ /\.\./
}
ENV["RUBYLIB"] = libdirs.join(":")

class TestPuppetCA < Test::Unit::TestCase
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        @@tmpfiles = []
    end

    def teardown
        @@tmpfiles.flatten.each { |file|
            if File.exists? file
                system("rm -rf %s" % file)
            end
        }
    end

    def mkcert(hostname)
        cert = nil
        assert_nothing_raised {
            cert = Puppet::SSLCertificates::Certificate.new(
                :name => hostname
            )
            cert.mkcsr
        }

        return cert
    end

    def test_signing
        ca = nil
        Puppet[:ssldir] = "/tmp/puppetcatest"
        @@tmpfiles << Puppet[:ssldir]
        Puppet[:autosign] = false
        assert_nothing_raised {
            ca = Puppet::CA.new()
        }
        #Puppet.warning "SSLDir is %s" % Puppet[:ssldir]
        #system("find %s" % Puppet[:ssldir])

        cert = mkcert("host.test.com")
        resp = nil
        assert_nothing_raised {
            resp = ca.getcert(cert.csr.to_pem)
        }
        assert_equal(["",""], resp)
        #Puppet.warning "SSLDir is %s" % Puppet[:ssldir]
        #system("find %s" % Puppet[:ssldir])

        output = nil
        assert_nothing_raised {
            output = %x{puppetca --list --ssldir=#{Puppet[:ssldir]} 2>&1}.chomp.split("\n")
        }
        #Puppet.warning "SSLDir is %s" % Puppet[:ssldir]
        #system("find %s" % Puppet[:ssldir])
        assert_equal($?,0)
        assert_equal(%w{host.test.com}, output)
        assert_nothing_raised {
            output = %x{puppetca --sign -a --ssldir=#{Puppet[:ssldir]}}.chomp.split("\n")
        }
        assert_equal($?,0)
        assert_equal([], output)
        assert_nothing_raised {
            output = %x{puppetca --list --ssldir=#{Puppet[:ssldir]}}.chomp.split("\n")
        }
        assert_equal($?,0)
        assert_equal([], output)
    end
end
