#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/network/handler/ca'
require 'mocha'

$short = (ARGV.length > 0 and ARGV[0] == "short")

class TestCA < Test::Unit::TestCase
  include PuppetTest::ServerTest

  def setup
    Puppet::Util::SUIDManager.stubs(:asuser).yields
    super
  end

  # Verify that we're autosigning.  We have to autosign a "different" machine,
  # since we always autosign the CA server's certificate.
  def test_autocertgeneration
    ca = nil

    # create our ca
    assert_nothing_raised {
      ca = Puppet::Network::Handler.ca.new(:autosign => true)
    }

    # create a cert with a fake name
    key = nil
    csr = nil
    cert = nil
    hostname = "test.domain.com"
    assert_nothing_raised {
      cert = Puppet::SSLCertificates::Certificate.new(
        :name => "test.domain.com"
      )
    }

    # make the request
    assert_nothing_raised {
      cert.mkcsr
    }

    # and get it signed
    certtext = nil
    cacerttext = nil
    assert_nothing_raised {
      certtext, cacerttext = ca.getcert(cert.csr.to_s)
    }

    # they should both be strings
    assert_instance_of(String, certtext)
    assert_instance_of(String, cacerttext)

    # and they should both be valid certs
    assert_nothing_raised {
      OpenSSL::X509::Certificate.new(certtext)
    }
    assert_nothing_raised {
      OpenSSL::X509::Certificate.new(cacerttext)
    }

    # and pull it again, just to make sure we're getting the same thing
    newtext = nil
    assert_nothing_raised {
      newtext, cacerttext = ca.getcert(
        cert.csr.to_s, "test.reductivelabs.com", "127.0.0.1"
      )
    }

    assert_equal(certtext,newtext)
  end

  # this time don't use autosign
  def test_storeAndSign
    ca = nil
    caserv = nil

    # make our CA server
    assert_nothing_raised {
      caserv = Puppet::Network::Handler.ca.new(:autosign => false)
    }

    # retrieve the actual ca object
    assert_nothing_raised {
      ca = caserv.ca
    }

    # make our test cert again
    key = nil
    csr = nil
    cert = nil
    hostname = "test.domain.com"
    assert_nothing_raised {
      cert = Puppet::SSLCertificates::Certificate.new(
        :name => "anothertest.domain.com"
      )
    }
    # and the CSR
    assert_nothing_raised {
      cert.mkcsr
    }

    # retrieve them
    certtext = nil
    assert_nothing_raised {
      certtext, cacerttext = caserv.getcert(
        cert.csr.to_s, "test.reductivelabs.com", "127.0.0.1"
      )
    }

    # verify we got nothing back, since autosign is off
    assert_equal("", certtext)

    # now sign it manually, with the CA object
    x509 = nil
    assert_nothing_raised {
      x509, cacert = ca.sign(cert.csr)
    }

    # and write it out
    cert.cert = x509
    assert_nothing_raised {
      cert.write
    }

    assert(File.exists?(cert.certfile))

    # now get them again, and verify that we actually get them
    newtext = nil
    assert_nothing_raised {
      newtext, cacerttext  = caserv.getcert(cert.csr.to_s)
    }

    assert(newtext)
    assert_nothing_raised {
      OpenSSL::X509::Certificate.new(newtext)
    }

    # Now verify that we can clean a given host's certs
    assert_nothing_raised {
      ca.clean("anothertest.domain.com")
    }

    assert(!File.exists?(cert.certfile), "Cert still exists after clean")
  end

  # and now test the autosign file
  def test_autosign
    autosign = File.join(tmpdir, "autosigntesting")
    @@tmpfiles << autosign
    File.open(autosign, "w") { |f|
      f.puts "hostmatch.domain.com"
      f.puts "*.other.com"
    }

    caserv = nil
    assert_nothing_raised {
      caserv = Puppet::Network::Handler.ca.new(:autosign => autosign)
    }

    # make sure we know what's going on
    assert(caserv.autosign?("hostmatch.domain.com"))
    assert(caserv.autosign?("fakehost.other.com"))
    assert(!caserv.autosign?("kirby.reductivelabs.com"))
    assert(!caserv.autosign?("culain.domain.com"))
  end

  # verify that things aren't autosigned by default
  def test_nodefaultautosign
    caserv = nil
    assert_nothing_raised {
      caserv = Puppet::Network::Handler.ca.new
    }

    # make sure we know what's going on
    assert(!caserv.autosign?("hostmatch.domain.com"))
    assert(!caserv.autosign?("fakehost.other.com"))
    assert(!caserv.autosign?("kirby.reductivelabs.com"))
    assert(!caserv.autosign?("culain.domain.com"))
  end

  # We want the CA to autosign its own certificate, because otherwise
  # the puppetmasterd CA does not autostart.
  def test_caautosign
    server = nil
    Puppet.stubs(:master?).returns true
    assert_nothing_raised {

            server = Puppet::Network::HTTPServer::WEBrick.new(
                
        :Port => @@port,
        
        :Handlers => {
          :CA => {}, # so that certs autogenerate
          :Status => nil
        }
      )
    }
  end

  # Make sure true/false causes the file to be ignored.
  def test_autosign_true_beats_file
    caserv = nil
    assert_nothing_raised {
      caserv = Puppet::Network::Handler.ca.new
    }

    host = "hostname.domain.com"

    # Create an autosign file
    file = tempfile
    Puppet[:autosign] = file

    File.open(file, "w") { |f|
      f.puts host
    }

    # Start with "false"
    Puppet[:autosign] = false

    assert(! caserv.autosign?(host), "Host was incorrectly autosigned")

    # Then set it to true
    Puppet[:autosign] = true
    assert(caserv.autosign?(host), "Host was not autosigned")
    # And try a different host
    assert(caserv.autosign?("other.yay.com"), "Host was not autosigned")

    # And lastly the file
    Puppet[:autosign] = file
    assert(caserv.autosign?(host), "Host was not autosigned")

    # And try a different host
    assert(! caserv.autosign?("other.yay.com"), "Host was autosigned")
  end

  # Make sure that a CSR created with keys that don't match the existing
  # cert throws an exception on the server.
  def test_mismatched_public_keys_throws_exception
    ca = Puppet::Network::Handler.ca.new

    # First initialize the server
    client = Puppet::Network::Client.ca.new :CA => ca
    client.request_cert
    File.unlink(Puppet[:hostcsr])

    # Now use a different cert name
    Puppet[:certname] = "my.host.com"
    client = Puppet::Network::Client.ca.new :CA => ca
    firstcsr = client.csr
    File.unlink(Puppet[:hostcsr]) if FileTest.exists?(Puppet[:hostcsr])

    assert_nothing_raised("Could not get cert") do
      ca.getcert(firstcsr.to_s)
    end

    # Now get rid of the public key, forcing a new csr
    File.unlink(Puppet[:hostprivkey])

    client = Puppet::Network::Client.ca.new :CA => ca

    second_csr = client.csr

    assert(firstcsr.to_s != second_csr.to_s, "CSR did not change")

    assert_raise(Puppet::Error, "CA allowed mismatched keys") do
      ca.getcert(second_csr.to_s)
    end
  end
end

