#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet/test_ca'

require 'puppet/ssl/host'
require 'matchers/json'
require 'puppet_spec/ssl'
require 'puppet/rest/routes'

def base_json_comparison(result, json_hash)
  expect(result["fingerprint"]).to eq(json_hash["fingerprint"])
  expect(result["name"]).to        eq(json_hash["name"])
  expect(result["state"]).to       eq(json_hash["desired_state"])
end

describe Puppet::SSL::Host, if: !Puppet::Util::Platform.jruby? do
  include JSONMatchers
  include PuppetSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("ssl_host_testing")
    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir
    Puppet.settings.use :main, :ssl

    @host = Puppet::SSL::Host.new("myname")
  end

  after do
    # Cleaned out any cached localhost instance.
    Puppet::SSL::Host.reset
  end

  it "should use any provided name as its name" do
    expect(@host.name).to eq("myname")
  end

  it "should retrieve its public key from its private key" do
    realkey = mock 'realkey'
    key = stub 'key', :content => realkey
    Puppet::SSL::Key.indirection.stubs(:find).returns(key)
    pubkey = mock 'public_key'
    realkey.expects(:public_key).returns pubkey

    expect(@host.public_key).to equal(pubkey)
  end

  describe 'localhost' do
    before(:each) do
      Puppet::SSL::Host.any_instance.stubs(:certificate).returns nil
      Puppet::SSL::Host.any_instance.stubs(:generate)
    end

    it "should have a method for producing an instance to manage the local host's keys" do
      expect(Puppet::SSL::Host).to respond_to(:localhost)
    end

    it "should allow to reset localhost" do
      previous_host = Puppet::SSL::Host.localhost
      Puppet::SSL::Host.reset
      expect(Puppet::SSL::Host.localhost).not_to eq(previous_host)
    end

    it "should generate the certificate for the localhost instance if no certificate is available" do
      host = stub 'host', :key => nil
      Puppet::SSL::Host.expects(:new).returns host

      host.expects(:certificate).returns nil
      host.expects(:generate)

      expect(Puppet::SSL::Host.localhost).to equal(host)
    end

    it "should always read the key for the localhost instance in from disk" do
      host = stub 'host', :certificate => "eh"
      host.expects(:key)
      Puppet::SSL::Host.expects(:new).returns host

      Puppet::SSL::Host.localhost
    end

    it "should cache the localhost instance" do
      host = stub 'host', :certificate => "eh", :key => 'foo'
      Puppet::SSL::Host.expects(:new).once.returns host
      expect(Puppet::SSL::Host.localhost).to eq(Puppet::SSL::Host.localhost)
    end
  end

  context "with dns_alt_names" do
    before :each do
      @key = stub('key content')
      key = stub('key', :generate => true, :content => @key)
      Puppet::SSL::Key.stubs(:new).returns key
      Puppet::SSL::Key.indirection.stubs(:save).with(key)

      @cr = stub('certificate request', :render => "csr pem")
      Puppet::SSL::CertificateRequest.stubs(:new).returns @cr
      Puppet::SSL::Host.any_instance.stubs(:submit_certificate_request)
    end

    describe "explicitly specified" do
      before :each do
        Puppet[:dns_alt_names] = 'one, two'
      end

      it "should not include subjectAltName if not the local node" do
        @cr.expects(:generate).with(@key, {})

        Puppet::SSL::Host.new('not-the-' + Puppet[:certname]).generate_certificate_request
      end

      it "should include subjectAltName if the local node" do
        @cr.expects(:generate).with(@key, { :dns_alt_names => 'one, two' })

        Puppet::SSL::Host.new(Puppet[:certname]).generate_certificate_request
      end
    end
  end

  it "should be able to verify its certificate matches its key" do
    expect(Puppet::SSL::Host.new("foo")).to respond_to(:validate_certificate_with_key)
  end

  it "should consider the certificate invalid if it cannot find a key" do
    host = Puppet::SSL::Host.new("foo")
    certificate = mock('cert', :fingerprint => 'DEADBEEF')
    host.expects(:key).returns nil
    expect { host.validate_certificate_with_key(certificate) }.to raise_error(Puppet::Error, "No private key with which to validate certificate with fingerprint: DEADBEEF")
  end

  it "should consider the certificate invalid if it cannot find a certificate" do
    host = Puppet::SSL::Host.new("foo")
    host.expects(:key).never
    expect { host.validate_certificate_with_key(nil) }.to raise_error(Puppet::Error, "No certificate to validate.")
  end

  it "should consider the certificate invalid if the SSL certificate's key verification fails" do
    host = Puppet::SSL::Host.new("foo")
    key = mock 'key', :content => "private_key"
    sslcert = mock 'sslcert'
    certificate = mock 'cert', {:content => sslcert, :fingerprint => 'DEADBEEF'}
    host.stubs(:key).returns key
    sslcert.expects(:check_private_key).with("private_key").returns false
    expect { host.validate_certificate_with_key(certificate) }.to raise_error(Puppet::Error, /DEADBEEF/)
  end

  it "should consider the certificate valid if the SSL certificate's key verification succeeds" do
    host = Puppet::SSL::Host.new("foo")
    key = mock 'key', :content => "private_key"
    sslcert = mock 'sslcert'
    certificate = mock 'cert', :content => sslcert
    host.stubs(:key).returns key
    sslcert.expects(:check_private_key).with("private_key").returns true
    expect{ host.validate_certificate_with_key(certificate) }.not_to raise_error
  end

  it "should output agent-specific commands when validation fails" do
    host = Puppet::SSL::Host.new("foo")
    key = mock 'key', :content => "private_key"
    sslcert = mock 'sslcert'
    certificate = mock 'cert', {:content => sslcert, :fingerprint => 'DEADBEEF'}
    host.stubs(:key).returns key
    sslcert.expects(:check_private_key).with("private_key").returns false
    expect { host.validate_certificate_with_key(certificate) }.to raise_error(Puppet::Error, /puppet ssl clean \n/)
  end

  it "should output device-specific commands when validation fails" do
    Puppet[:certname] = "device.example.com"
    host = Puppet::SSL::Host.new("device.example.com", true)
    key = mock 'key', :content => "private_key"
    sslcert = mock 'sslcert'
    certificate = mock 'cert', {:content => sslcert, :fingerprint => 'DEADBEEF'}
    host.stubs(:key).returns key
    sslcert.expects(:check_private_key).with("private_key").returns false
    expect { host.validate_certificate_with_key(certificate) }.to raise_error(Puppet::Error, /puppet ssl clean --target device.example.com/)
  end

  describe "when initializing" do
    it "should default its name to the :certname setting" do
      Puppet[:certname] = "myname"

      expect(Puppet::SSL::Host.new.name).to eq("myname")
    end

    it "should downcase a passed in name" do
      expect(Puppet::SSL::Host.new("Host.Domain.Com").name).to eq("host.domain.com")
    end
  end

  describe "when managing its private key" do
    before do
      @realkey = "mykey"
      @key = Puppet::SSL::Key.new("mykey")
      @key.content = @realkey
    end

    it "should return nil if the key is not set and cannot be found" do
      Puppet::SSL::Key.indirection.expects(:find).with("myname").returns(nil)
      expect(@host.key).to be_nil
    end

    it "should find the key in the Key class and return the Puppet instance" do
      Puppet::SSL::Key.indirection.expects(:find).with("myname").returns(@key)
      expect(@host.key).to equal(@key)
    end

    it "should be able to generate and save a new key" do
      Puppet::SSL::Key.expects(:new).with("myname").returns(@key)

      @key.expects(:generate)
      Puppet::SSL::Key.indirection.expects(:save)

      expect(@host.generate_key).to be_truthy
      expect(@host.key).to equal(@key)
    end

    it "should not retain keys that could not be saved" do
      Puppet::SSL::Key.expects(:new).with("myname").returns(@key)

      @key.stubs(:generate)
      Puppet::SSL::Key.indirection.expects(:save).raises "eh"

      expect { @host.generate_key }.to raise_error(RuntimeError)
      expect(@host.key).to be_nil
    end

    it "should return any previously found key without requerying" do
      Puppet::SSL::Key.indirection.expects(:find).with("myname").returns(@key).once
      expect(@host.key).to equal(@key)
      expect(@host.key).to equal(@key)
    end
  end

  describe "when managing its certificate request" do
    before(:all) do
      @pki = PuppetSpec::SSL.create_chained_pki
    end

    before(:each) do
      Puppet[:requestdir] = tmpdir('requests')
    end

    let(:key) { Puppet::SSL::Key.from_s(@pki[:leaf_key].to_s, @host.name) }

    it "should generate a new key when generating the cert request if no key exists" do
      @host.expects(:key).times(2).returns(nil).then.returns(key)
      @host.expects(:generate_key).returns(key)

      @host.stubs(:submit_certificate_request)

      @host.generate_certificate_request
      expect(Puppet::FileSystem.exist?(File.join(Puppet[:requestdir], "#{@host.name}.pem"))).to be true
    end

    it "should be able to generate and save a new request using the private key" do
      @host.stubs(:key).returns(key)
      @host.stubs(:submit_certificate_request)

      expect(@host.generate_certificate_request).to be_truthy
      expect(Puppet::FileSystem.exist?(File.join(Puppet[:requestdir], "#{@host.name}.pem"))).to be true
    end

    it "should send a new request to the CA for signing" do
      @http = mock("http")
      @host.stubs(:http_client).returns(@http)
      @host.stubs(:ssl_store).returns(mock("ssl store"))
      @host.stubs(:key).returns(key)
      request = mock("request")
      request.stubs(:generate)
      request.expects(:render).returns("my request").twice
      Puppet::SSL::CertificateRequest.expects(:new).returns(request)

      Puppet::Rest::Routes.expects(:put_certificate_request)
        .with("my request", @host.name, anything)
        .returns(nil)

      expect(@host.generate_certificate_request).to be true
    end

    it "should return any previously found request without requerying" do
      request = mock("request")
      @host.expects(:load_certificate_request_from_file).returns(request).once

      expect(@host.certificate_request).to equal(request)
      expect(@host.certificate_request).to equal(request)
    end

    it "should not keep its certificate request in memory if the request cannot be saved" do
      @host.stubs(:key).returns(key)
      @host.stubs(:submit_certificate_request)
      Puppet::Util.expects(:replace_file).raises(RuntimeError)

      expect { @host.generate_certificate_request }.to raise_error(RuntimeError)

      expect(@host.instance_eval { @certificate_request }).to be_nil
    end
  end

  describe "when managing its certificate" do
    before(:all) do
      @pki = PuppetSpec::SSL.create_chained_pki
    end

    before(:each) do
      Puppet[:certdir] = tmpdir('certs')
      @host.stubs(:key).returns mock("key")
      @host.stubs(:validate_certificate_with_key)
      @host.stubs(:http_client).returns(@http)
      @host.stubs(:ssl_store).returns(mock("ssl store"))
    end

    let(:ca_cert_response) { @pki[:ca_bundle] }
    let(:host_cert_response) { @pki[:unrevoked_leaf_node_cert] }

    it "should find the CA certificate and save it to disk" do
      Puppet::Rest::Routes.expects(:get_certificate)
                          .with(Puppet::SSL::CA_NAME, anything)
                          .returns(ca_cert_response)
      Puppet::Rest::Routes.expects(:get_certificate)
                          .with(@host.name, anything)
                          .raises(Puppet::Rest::ResponseError.new('no client cert',
                                                                  mock('response', code: '404')))
      @host.certificate
      actual_ca_bundle = Puppet::FileSystem.read(Puppet[:localcacert])
      expect(actual_ca_bundle).to match(/BEGIN CERTIFICATE.*END CERTIFICATE.*BEGIN CERTIFICATE/m)
    end

    it "should return nil if it cannot find a CA certificate" do
      @host.expects(:ensure_ca_certificate).returns(false)
      @host.expects(:get_host_certificate).never

      expect(@host.certificate).to be_nil
    end

    it "should find the key if it does not have one" do
      @host.expects(:ensure_ca_certificate).returns(true)
      @host.expects(:get_host_certificate).returns(nil)
      @host.expects(:key).returns mock("key")
      @host.certificate
    end

    it "should generate the key if one cannot be found" do
      @host.expects(:ensure_ca_certificate).returns(true)
      @host.expects(:get_host_certificate).returns(nil)
      @host.expects(:key).returns nil
      @host.expects(:generate_key)
      @host.certificate
    end

    it "should find the host certificate, write it to file, and return the Puppet certificate instance" do
      Puppet::Rest::Routes.expects(:get_certificate)
                          .with(Puppet::SSL::CA_NAME, anything)
                          .returns(ca_cert_response)
      Puppet::Rest::Routes.expects(:get_certificate)
                          .with(@host.name, anything)
                          .returns(host_cert_response)
      expected_cert = Puppet::SSL::Certificate.from_s(@pki[:unrevoked_leaf_node_cert])
      actual_cert = @host.certificate
      expect(actual_cert).to be_a(Puppet::SSL::Certificate)
      expect(actual_cert.to_s).to eq(expected_cert.to_s)
      host_cert_from_file = Puppet::FileSystem.read(File.join(Puppet[:certdir], "#{@host.name}.pem"))
      expect(host_cert_from_file).to eq(expected_cert.to_s)
    end

    it "should return any previously found certificate" do
      cert = mock 'cert'
      @host.expects(:ensure_ca_certificate).returns(true).once
      @host.expects(:get_host_certificate).returns(cert).once

      expect(@host.certificate).to equal(cert)
      expect(@host.certificate).to equal(cert)
    end

    context 'invalid certificates' do
      it "should raise if the CA certificate downloaded from CA is invalid" do
        Puppet::Rest::Routes.expects(:get_certificate)
                            .with(Puppet::SSL::CA_NAME, anything)
                            .returns('garbage')
        expect { @host.certificate }.to raise_error(Puppet::Error, /did not contain a valid CA certificate/)
      end

      it "should warn if the host certificate downloaded from CA is invalid" do
        Puppet::Rest::Routes.expects(:get_certificate)
                            .with(Puppet::SSL::CA_NAME, anything)
                            .returns(ca_cert_response)
        Puppet::Rest::Routes.expects(:get_certificate)
                            .with(@host.name, anything)
                            .returns('garbage')
        expect { @host.certificate }.to raise_error(Puppet::Error, /did not contain a valid certificate for #{@host.name}/)
      end

      it 'should warn if the CA certificate loaded from disk is invalid' do
        Puppet::FileSystem.open(Puppet[:localcacert], nil, "w:ASCII") do |f|
          f.puts 'garbage'
        end
        expect { @host.certificate }.to raise_error(Puppet::Error, /The CA certificate.*invalid/)
      end

      it 'should warn if the host certificate loaded from disk in invalid' do
        Puppet::Rest::Routes.expects(:get_certificate)
                            .with(Puppet::SSL::CA_NAME, anything)
                            .returns(ca_cert_response)
        Puppet::FileSystem.open(File.join(Puppet[:certdir], "#{@host.name}.pem"), nil, "w:ASCII") do |f|
          f.puts 'garbage'
        end
        expect { @host.certificate }.to raise_error(Puppet::Error, /The certificate.*invalid/)
      end
    end
  end

  it "should have a method for generating all necessary files" do
    expect(Puppet::SSL::Host.new("me")).to respond_to(:generate)
  end

  describe "when generating files" do
    before do
      @host = Puppet::SSL::Host.new("me")
      @host.stubs(:generate_key)
      @host.stubs(:generate_certificate_request)
      @host.stubs(:certificate_request)
      @host.stubs(:certificate)
    end

    it "should generate a key if one is not present" do
      @host.stubs(:key).returns nil
      @host.expects(:generate_key)

      @host.generate
    end

    it "should generate a certificate request if one is not present" do
      @host.expects(:certificate_request).returns nil
      @host.expects(:generate_certificate_request)

      @host.generate
    end
  end

  it "should have a method for creating an SSL store" do
    expect(Puppet::SSL::Host.new("me")).to respond_to(:ssl_store)
  end

  describe "when creating an SSL store" do
    before do
      Puppet[:localcacert] = "ssl_host_testing"
    end

    it "should accept a purpose" do
      store = mock 'store'
      store.stub_everything
      OpenSSL::X509::Store.expects(:new).returns store
      store.expects(:purpose=).with(OpenSSL::X509::PURPOSE_SSL_SERVER)
      host = Puppet::SSL::Host.new("me")
      host.crl_usage = false

      host.ssl_store(OpenSSL::X509::PURPOSE_SSL_SERVER)
    end

    context "and the CRL is not on disk" do
      before do
        @pki = PuppetSpec::SSL.create_chained_pki
        @revoked_cert = @pki[:revoked_root_node_cert]
        localcacert = Puppet.settings[:localcacert]
        Puppet::Util.replace_file(localcacert, 0644) {|f| f.write @pki[:ca_bundle] }
        @http = mock 'http'
        @host.stubs(:http_client).returns(@http)
      end

      after do
        Puppet::FileSystem.unlink(Puppet.settings[:localcacert])
        Puppet::FileSystem.unlink(Puppet.settings[:hostcrl])
      end

      it "retrieves it from the server" do
        Puppet::Rest::Routes.expects(:get_crls)
          .with(Puppet::SSL::CA_NAME, anything)
          .returns(@pki[:crl_chain])

        @host.ssl_store
        expect(Puppet::FileSystem.read(Puppet.settings[:hostcrl], :encoding => Encoding::UTF_8)).to eq(@pki[:crl_chain])
      end
    end

    describe "and a CRL is available" do
      before do
        pki = PuppetSpec::SSL.create_chained_pki

        @revoked_cert_from_self_signed_root          = pki[:revoked_root_node_cert]
        @revoked_cert_from_ca_with_untrusted_chain   = pki[:revoked_leaf_node_cert]
        @unrevoked_cert_from_self_signed_root        = pki[:unrevoked_root_node_cert]
        @unrevoked_cert_from_revoked_ca              = pki[:unrevoked_int_node_cert]
        @unrevoked_cert_from_ca_with_untrusted_chain = pki[:unrevoked_leaf_node_cert]

        localcacert = Puppet.settings[:localcacert]
        hostcrl     = Puppet.settings[:hostcrl]

        Puppet::Util.replace_file(localcacert, 0644) {|f| f.write pki[:ca_bundle] }
        Puppet::Util.replace_file(hostcrl, 0644)     {|f| f.write pki[:crl_chain] }
      end

      after do
        Puppet::FileSystem.unlink(Puppet.settings[:localcacert])
        Puppet::FileSystem.unlink(Puppet.settings[:hostcrl])
      end

      [true, :chain].each do |crl_setting|
        describe "and 'certificate_revocation' is #{crl_setting}" do
          before do
            @host = Puppet::SSL::Host.new(crl_setting.to_s)
            @host.crl_usage = crl_setting
          end

          it "should verify unrevoked certs" do
            expect(
              @host.ssl_store.verify(@unrevoked_cert_from_self_signed_root)
            ).to be true
          end

          it "should not verify revoked certs" do
            [@revoked_cert_from_self_signed_root,
             @revoked_cert_from_ca_with_untrusted_chain,
             @unrevoked_cert_from_revoked_ca,
             @unrevoked_cert_from_ca_with_untrusted_chain].each do |cert|
              expect(@host.ssl_store.verify(cert)).to be false
            end
          end
        end
      end

      describe "and 'certificate_revocation' is leaf" do
        before do
          @host = Puppet::SSL::Host.new("leaf")
          @host.crl_usage = :leaf
        end

        it "should verify unrevoked certs regardless of signing CA's revocation status" do
          [@unrevoked_cert_from_self_signed_root,
           @unrevoked_cert_from_revoked_ca,
           @unrevoked_cert_from_ca_with_untrusted_chain].each do |cert|
            expect(@host.ssl_store.verify(cert)).to be true
          end
        end

        it "should not verify certs revoked by their signing CA" do
          [@revoked_cert_from_self_signed_root,
           @revoked_cert_from_ca_with_untrusted_chain].each do |cert|
            expect(@host.ssl_store.verify(cert)).to be false
          end
        end
      end

      describe "and 'certificate_revocation' is false" do
        before do
          @host = Puppet::SSL::Host.new("host")
          @host.crl_usage = false
        end

        it "should verify valid certs regardless of revocation status" do
          [@revoked_cert_from_self_signed_root,
           @revoked_cert_from_ca_with_untrusted_chain,
           @unrevoked_cert_from_self_signed_root,
           @unrevoked_cert_from_revoked_ca,
           @unrevoked_cert_from_ca_with_untrusted_chain].each do |cert|
            expect(@host.ssl_store.verify(cert)).to be true
          end
        end
      end
    end
  end

  describe "when waiting for a cert" do
    before do
      @host = Puppet::SSL::Host.new("me")
    end

    it "should generate its certificate request and attempt to read the certificate again if no certificate is found" do
      @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
      @host.expects(:generate)
      @host.wait_for_cert(1)
    end

    it "should catch and log errors during CSR saving" do
      @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
      @host.expects(:generate).raises(RuntimeError).then.returns nil
      @host.stubs(:sleep)
      @host.wait_for_cert(1)
    end

    it "should sleep and retry after failures saving the CSR if waitforcert is enabled" do
      @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
      @host.expects(:generate).raises(RuntimeError).then.returns nil
      @host.expects(:sleep).with(1)
      @host.wait_for_cert(1)
    end

    it "should exit after failures saving the CSR of waitforcert is disabled" do
      @host.expects(:certificate).returns(nil)
      @host.expects(:generate).raises(RuntimeError)
      @host.expects(:puts)
      expect { @host.wait_for_cert(0) }.to exit_with 1
    end

    it "should exit if the wait time is 0 and it can neither find nor retrieve a certificate" do
      @host.stubs(:certificate).returns nil
      @host.expects(:generate)
      @host.expects(:puts)
      expect { @host.wait_for_cert(0) }.to exit_with 1
    end

    it "should sleep for the specified amount of time if no certificate is found after generating its certificate request" do
      @host.expects(:certificate).times(3).returns(nil).then.returns(nil).then.returns "foo"
      @host.expects(:generate)

      @host.expects(:sleep).with(1)

      @host.wait_for_cert(1)
    end

    it "should catch and log exceptions during certificate retrieval" do
      @host.expects(:certificate).times(3).returns(nil).then.raises(RuntimeError).then.returns("foo")
      @host.stubs(:generate)
      @host.stubs(:sleep)

      Puppet.expects(:log_exception)

      @host.wait_for_cert(1)
    end
  end
end
