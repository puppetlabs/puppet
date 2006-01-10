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

class TestPuppetCA < Test::Unit::TestCase
	include ExeTest
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
        Puppet[:ssldir] = tempfile()
        @@tmpfiles << Puppet[:ssldir]
        Puppet[:autosign] = false
        assert_nothing_raised {
            ca = Puppet::Server::CA.new()
        }
        #Puppet.warning "SSLDir is %s" % Puppet[:ssldir]
        #system("find %s" % Puppet[:ssldir])

        cert = mkcert("host.test.com")
        resp = nil
        assert_nothing_raised {
            # We need to use a fake name so it doesn't think the cert is from
            # itself.
            resp = ca.getcert(cert.csr.to_pem, "fakename", "127.0.0.1")
        }
        assert_equal(["",""], resp)
        #Puppet.warning "SSLDir is %s" % Puppet[:ssldir]
        #system("find %s" % Puppet[:ssldir])

        output = nil
        assert_nothing_raised {
            output = %x{puppetca --list --ssldir=#{Puppet[:ssldir]} 2>&1}.chomp.split("\n").reject { |line| line =~ /warning:/ } # stupid ssl.rb
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

# $Id$
