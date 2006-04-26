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
    
    def runca(args)
        debug = ""
        if Puppet[:debug]
            debug = "-d "
        end
        return %x{puppetca --user=#{Puppet[:user]} #{debug} --group=#{Puppet[:group]} --confdir=#{Puppet[:confdir]} #{args} 2>&1}

    end

    def test_signing
        ca = nil
        Puppet[:autosign] = false
        assert_nothing_raised {
            ca = Puppet::Server::CA.new()
        }
        #Puppet.warning "SSLDir is %s" % Puppet[:confdir]
        #system("find %s" % Puppet[:confdir])

        cert = mkcert("host.test.com")
        resp = nil
        assert_nothing_raised {
            # We need to use a fake name so it doesn't think the cert is from
            # itself.
            resp = ca.getcert(cert.csr.to_pem, "fakename", "127.0.0.1")
        }
        assert_equal(["",""], resp)
        #Puppet.warning "SSLDir is %s" % Puppet[:confdir]
        #system("find %s" % Puppet[:confdir])

        output = nil
        assert_nothing_raised {
            output = runca("--list").chomp.split("\n").reject { |line| line =~ /warning:/ } # stupid ssl.rb
        }
        #Puppet.warning "SSLDir is %s" % Puppet[:confdir]
        #system("find %s" % Puppet[:confdir])
        assert_equal($?,0)
        assert_equal(%w{host.test.com}, output)
        assert_nothing_raised {
            output = runca("--sign -a").chomp.split("\n")
        }


        assert_equal($?,0)
        assert_equal(["Signed host.test.com"], output)

        signedfile = File.join(Puppet[:signeddir], "host.test.com.pem")
        assert(FileTest.exists?(signedfile), "cert does not exist")
        assert(! FileTest.executable?(signedfile), "cert is executable")

        uid = Puppet::Util.uid(Puppet[:user])

        if Process.uid == 0
            assert(! FileTest.owned?(signedfile), "cert is owned by root")
        end
        assert_nothing_raised {
            output = runca("--list").chomp.split("\n")
        }
        assert_equal($?,0)
        assert_equal(["No certificates to sign"], output)
    end
end

# $Id$
