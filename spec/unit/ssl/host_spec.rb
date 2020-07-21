require 'spec_helper'

require 'puppet/ssl/host'
require 'matchers/json'

def base_json_comparison(result, json_hash)
  expect(result["fingerprint"]).to eq(json_hash["fingerprint"])
  expect(result["name"]).to        eq(json_hash["name"])
  expect(result["state"]).to       eq(json_hash["desired_state"])
end

describe Puppet::SSL::Host do
  include JSONMatchers
  include PuppetSpec::Files

  before do
    Puppet::SSL::Host.indirection.terminus_class = :file

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
    Puppet::SSL::Host.ca_location = :none
  end

  it "should use any provided name as its name" do
    expect(@host.name).to eq("myname")
  end

  it "should retrieve its public key from its private key" do
    realkey = double('realkey')
    key = double('key', :content => realkey)
    allow(Puppet::SSL::Key.indirection).to receive(:find).and_return(key)
    pubkey = double('public_key')
    expect(realkey).to receive(:public_key).and_return(pubkey)

    expect(@host.public_key).to equal(pubkey)
  end

  it "should default to being a non-ca host" do
    expect(@host.ca?).to be_falsey
  end

  it "should be a ca host if its name matches the CA_NAME" do
    allow(Puppet::SSL::Host).to receive(:ca_name).and_return("yayca")
    expect(Puppet::SSL::Host.new("yayca")).to be_ca
  end

  it "should have a method for determining the CA location" do
    expect(Puppet::SSL::Host).to respond_to(:ca_location)
  end

  it "should have a method for specifying the CA location" do
    expect(Puppet::SSL::Host).to respond_to(:ca_location=)
  end

  it "should have a method for retrieving the default ssl host" do
    expect(Puppet::SSL::Host).to respond_to(:ca_location=)
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
    host = double('host', :key => nil)
    expect(Puppet::SSL::Host).to receive(:new).and_return(host)

    expect(host).to receive(:certificate).and_return(nil)
    expect(host).to receive(:generate)

    expect(Puppet::SSL::Host.localhost).to equal(host)
  end

  it "should create a localhost cert if no cert is available and it is a CA with autosign and it is using DNS alt names", :unless => Puppet.features.microsoft_windows? do
    Puppet[:autosign] = true
    Puppet[:confdir] = tmpdir('conf')
    Puppet[:dns_alt_names] = "foo,bar,baz"
    ca = Puppet::SSL::CertificateAuthority.new
    allow(Puppet::SSL::CertificateAuthority).to receive(:instance).and_return(ca)

    localhost = Puppet::SSL::Host.localhost
    cert = localhost.certificate

    expect(cert).to be_a(Puppet::SSL::Certificate)
    expect(cert.subject_alt_names).to match_array(%W[DNS:#{Puppet[:certname]} DNS:foo DNS:bar DNS:baz])
  end

  context "with dns_alt_names" do
    before :each do
      @key = double('key content')
      key = double('key', :generate => true, :content => @key)
      allow(Puppet::SSL::Key).to receive(:new).and_return(key)
      allow(Puppet::SSL::Key.indirection).to receive(:save).with(key)

      @cr = double('certificate request')
      allow(Puppet::SSL::CertificateRequest).to receive(:new).and_return(@cr)
      allow(Puppet::SSL::CertificateRequest.indirection).to receive(:save).with(@cr)
    end

    describe "explicitly specified" do
      before :each do
        Puppet[:dns_alt_names] = 'one, two'
      end

      it "should not include subjectAltName if not the local node" do
        expect(@cr).to receive(:generate).with(@key, {})

        Puppet::SSL::Host.new('not-the-' + Puppet[:certname]).generate
      end

      it "should include subjectAltName if I am a CA" do
        expect(@cr).to receive(:generate).
          with(@key, { :dns_alt_names => Puppet[:dns_alt_names] })

        Puppet::SSL::Host.localhost
      end
    end

    describe "implicitly defaulted" do
      let(:ca) { double('ca', :sign => nil) }

      before :each do
        Puppet[:dns_alt_names] = ''

        allow(Puppet::SSL::CertificateAuthority).to receive(:instance).and_return(ca)
      end

      it "should not include defaults if we're not the CA" do
        allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(false)

        expect(@cr).to receive(:generate).with(@key, {})

        Puppet::SSL::Host.localhost
      end

      it "should not include defaults if not the local node" do
        allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(true)

        expect(@cr).to receive(:generate).with(@key, {})

        Puppet::SSL::Host.new('not-the-' + Puppet[:certname]).generate
      end

      it "should not include defaults if we can't resolve our fqdn" do
        allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(true)
        allow(Facter).to receive(:value).and_call_original
        allow(Facter).to receive(:value).with(:fqdn).and_return(nil)

        expect(@cr).to receive(:generate).with(@key, {})

        Puppet::SSL::Host.localhost
      end

      it "should provide defaults if we're bootstrapping the local master" do
        allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(true)
        allow(Facter).to receive(:value).and_call_original
        allow(Facter).to receive(:value).with(:fqdn).and_return('web.foo.com')
        allow(Facter).to receive(:value).with(:domain).and_return('foo.com')

        expect(@cr).to receive(:generate).with(@key, {:dns_alt_names => "puppet, web.foo.com, puppet.foo.com"})

        Puppet::SSL::Host.localhost
      end
    end
  end

  it "should always read the key for the localhost instance in from disk" do
    host = double('host', :certificate => "eh")
    expect(Puppet::SSL::Host).to receive(:new).and_return(host)

    expect(host).to receive(:key)

    Puppet::SSL::Host.localhost
  end

  it "should cache the localhost instance" do
    host = double('host', :certificate => "eh", :key => 'foo')
    expect(Puppet::SSL::Host).to receive(:new).once.and_return(host)
    expect(Puppet::SSL::Host.localhost).to eq(Puppet::SSL::Host.localhost)
  end

  it "should be able to verify its certificate matches its key" do
    expect(Puppet::SSL::Host.new("foo")).to respond_to(:validate_certificate_with_key)
  end

  it "should consider the certificate invalid if it cannot find a key" do
    host = Puppet::SSL::Host.new("foo")
    certificate = double('cert', :fingerprint => 'DEADBEEF')
    expect(host).to receive(:certificate).twice.and_return(certificate)
    expect(host).to receive(:key).and_return(nil)
    expect { host.validate_certificate_with_key }.to raise_error(Puppet::Error, "No private key with which to validate certificate with fingerprint: DEADBEEF")
  end

  it "should consider the certificate invalid if it cannot find a certificate" do
    host = Puppet::SSL::Host.new("foo")
    expect(host).not_to receive(:key)
    expect(host).to receive(:certificate).and_return(nil)
    expect { host.validate_certificate_with_key }.to raise_error(Puppet::Error, "No certificate to validate.")
  end

  it "should consider the certificate invalid if the SSL certificate's key verification fails" do
    host = Puppet::SSL::Host.new("foo")
    key = double('key', :content => "private_key")
    sslcert = double('sslcert')
    certificate = double('cert', {:content => sslcert, :fingerprint => 'DEADBEEF'})
    allow(host).to receive(:key).and_return(key)
    allow(host).to receive(:certificate).and_return(certificate)
    expect(sslcert).to receive(:check_private_key).with("private_key").and_return(false)
    expect { host.validate_certificate_with_key }.to raise_error(Puppet::Error, /DEADBEEF/)
  end

  it "should consider the certificate valid if the SSL certificate's key verification succeeds" do
    host = Puppet::SSL::Host.new("foo")
    key = double('key', :content => "private_key")
    sslcert = double('sslcert')
    certificate = double('cert', :content => sslcert)
    allow(host).to receive(:key).and_return(key)
    allow(host).to receive(:certificate).and_return(certificate)
    expect(sslcert).to receive(:check_private_key).with("private_key").and_return(true)
    expect{ host.validate_certificate_with_key }.not_to raise_error
  end

  describe "when specifying the CA location" do
    it "should support the location ':local'" do
      expect { Puppet::SSL::Host.ca_location = :local }.not_to raise_error
    end

    it "should support the location ':remote'" do
      expect { Puppet::SSL::Host.ca_location = :remote }.not_to raise_error
    end

    it "should support the location ':none'" do
      expect { Puppet::SSL::Host.ca_location = :none }.not_to raise_error
    end

    it "should support the location ':only'" do
      expect { Puppet::SSL::Host.ca_location = :only }.not_to raise_error
    end

    it "should not support other modes" do
      expect { Puppet::SSL::Host.ca_location = :whatever }.to raise_error(ArgumentError)
    end

    describe "as 'local'" do
      before do
        Puppet::SSL::Host.ca_location = :local
      end

      it "should set the cache class for Certificate, CertificateRevocationList, and CertificateRequest as :file" do
        expect(Puppet::SSL::Certificate.indirection.cache_class).to eq(:file)
        expect(Puppet::SSL::CertificateRequest.indirection.cache_class).to eq(:file)
        expect(Puppet::SSL::CertificateRevocationList.indirection.cache_class).to eq(:file)
      end

      it "should set the terminus class for Key and Host as :file" do
        expect(Puppet::SSL::Key.indirection.terminus_class).to eq(:file)
        expect(Puppet::SSL::Host.indirection.terminus_class).to eq(:file)
      end

      it "should set the terminus class for Certificate, CertificateRevocationList, and CertificateRequest as :ca" do
        expect(Puppet::SSL::Certificate.indirection.terminus_class).to eq(:ca)
        expect(Puppet::SSL::CertificateRequest.indirection.terminus_class).to eq(:ca)
        expect(Puppet::SSL::CertificateRevocationList.indirection.terminus_class).to eq(:ca)
      end
    end

    describe "as 'remote'" do
      before do
        Puppet::SSL::Host.ca_location = :remote
      end

      it "should set the cache class for Certificate, CertificateRevocationList, and CertificateRequest as :file" do
        expect(Puppet::SSL::Certificate.indirection.cache_class).to eq(:file)
        expect(Puppet::SSL::CertificateRequest.indirection.cache_class).to eq(:file)
        expect(Puppet::SSL::CertificateRevocationList.indirection.cache_class).to eq(:file)
      end

      it "should set the terminus class for Key as :file" do
        expect(Puppet::SSL::Key.indirection.terminus_class).to eq(:file)
      end

      it "should set the terminus class for Host, Certificate, CertificateRevocationList, and CertificateRequest as :rest" do
        expect(Puppet::SSL::Host.indirection.terminus_class).to eq(:rest)
        expect(Puppet::SSL::Certificate.indirection.terminus_class).to eq(:rest)
        expect(Puppet::SSL::CertificateRequest.indirection.terminus_class).to eq(:rest)
        expect(Puppet::SSL::CertificateRevocationList.indirection.terminus_class).to eq(:rest)
      end
    end

    describe "as 'only'" do
      before do
        Puppet::SSL::Host.ca_location = :only
      end

      it "should set the terminus class for Key, Certificate, CertificateRevocationList, and CertificateRequest as :ca" do
        expect(Puppet::SSL::Key.indirection.terminus_class).to eq(:ca)
        expect(Puppet::SSL::Certificate.indirection.terminus_class).to eq(:ca)
        expect(Puppet::SSL::CertificateRequest.indirection.terminus_class).to eq(:ca)
        expect(Puppet::SSL::CertificateRevocationList.indirection.terminus_class).to eq(:ca)
      end

      it "should set the cache class for Certificate, CertificateRevocationList, and CertificateRequest to nil" do
        expect(Puppet::SSL::Certificate.indirection.cache_class).to be_nil
        expect(Puppet::SSL::CertificateRequest.indirection.cache_class).to be_nil
        expect(Puppet::SSL::CertificateRevocationList.indirection.cache_class).to be_nil
      end

      it "should set the terminus class for Host to :file" do
        expect(Puppet::SSL::Host.indirection.terminus_class).to eq(:file)
      end
    end

    describe "as 'none'" do
      before do
        Puppet::SSL::Host.ca_location = :none
      end

      it "should set the terminus class for Key, Certificate, CertificateRevocationList, and CertificateRequest as :file" do
        expect(Puppet::SSL::Key.indirection.terminus_class).to eq(:disabled_ca)
        expect(Puppet::SSL::Certificate.indirection.terminus_class).to eq(:disabled_ca)
        expect(Puppet::SSL::CertificateRequest.indirection.terminus_class).to eq(:disabled_ca)
        expect(Puppet::SSL::CertificateRevocationList.indirection.terminus_class).to eq(:disabled_ca)
      end

      it "should set the terminus class for Host to 'none'" do
        expect { Puppet::SSL::Host.indirection.terminus_class }.to raise_error(Puppet::DevError)
      end
    end
  end

  it "should have a class method for destroying all files related to a given host" do
    expect(Puppet::SSL::Host).to respond_to(:destroy)
  end

  describe "when destroying a host's SSL files" do
    before do
      allow(Puppet::SSL::Key.indirection).to receive(:destroy).and_return(false)
      allow(Puppet::SSL::Certificate.indirection).to receive(:destroy).and_return(false)
      allow(Puppet::SSL::CertificateRequest.indirection).to receive(:destroy).and_return(false)
    end

    it "should destroy its certificate, certificate request, and key" do
      expect(Puppet::SSL::Key.indirection).to receive(:destroy).with("myhost")
      expect(Puppet::SSL::Certificate.indirection).to receive(:destroy).with("myhost")
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:destroy).with("myhost")

      Puppet::SSL::Host.destroy("myhost")
    end

    it "should return true if any of the classes returned true" do
      expect(Puppet::SSL::Certificate.indirection).to receive(:destroy).with("myhost").and_return(true)

      expect(Puppet::SSL::Host.destroy("myhost")).to be_truthy
    end

    it "should report that nothing was deleted if none of the classes returned true" do
      expect(Puppet::SSL::Host.destroy("myhost")).to eq("Nothing was deleted")
    end
  end

  describe "when initializing" do
    it "should default its name to the :certname setting" do
      Puppet[:certname] = "myname"

      expect(Puppet::SSL::Host.new.name).to eq("myname")
    end

    it "should downcase a passed in name" do
      expect(Puppet::SSL::Host.new("Host.Domain.Com").name).to eq("host.domain.com")
    end

    it "should indicate that it is a CA host if its name matches the ca_name constant" do
      allow(Puppet::SSL::Host).to receive(:ca_name).and_return("myca")
      expect(Puppet::SSL::Host.new("myca")).to be_ca
    end
  end

  describe "when managing its private key" do
    before do
      @realkey = "mykey"
      @key = Puppet::SSL::Key.new("mykey")
      @key.content = @realkey
    end

    it "should return nil if the key is not set and cannot be found" do
      expect(Puppet::SSL::Key.indirection).to receive(:find).with("myname").and_return(nil)
      expect(@host.key).to be_nil
    end

    it "should find the key in the Key class and return the Puppet instance" do
      expect(Puppet::SSL::Key.indirection).to receive(:find).with("myname").and_return(@key)
      expect(@host.key).to equal(@key)
    end

    it "should be able to generate and save a new key" do
      expect(Puppet::SSL::Key).to receive(:new).with("myname").and_return(@key)

      expect(@key).to receive(:generate)
      expect(Puppet::SSL::Key.indirection).to receive(:save)

      expect(@host.generate_key).to be_truthy
      expect(@host.key).to equal(@key)
    end

    it "should not retain keys that could not be saved" do
      expect(Puppet::SSL::Key).to receive(:new).with("myname").and_return(@key)

      expect(@key).to receive(:generate)
      expect(Puppet::SSL::Key.indirection).to receive(:save).and_raise("eh")

      expect { @host.generate_key }.to raise_error(RuntimeError)
      expect(@host.key).to be_nil
    end

    it "should return any previously found key without requerying" do
      expect(Puppet::SSL::Key.indirection).to receive(:find).with("myname").and_return(@key).once
      expect(@host.key).to equal(@key)
      expect(@host.key).to equal(@key)
    end
  end

  describe "when managing its certificate request" do
    before do
      @realrequest = "real request"
      @request = Puppet::SSL::CertificateRequest.new("myname")
      @request.content = @realrequest
    end

    it "should return nil if the key is not set and cannot be found" do
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("myname").and_return(nil)
      expect(@host.certificate_request).to be_nil
    end

    it "should find the request in the Key class and return it and return the Puppet SSL request" do
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("myname").and_return(@request)

      expect(@host.certificate_request).to equal(@request)
    end

    it "should generate a new key when generating the cert request if no key exists" do
      expect(Puppet::SSL::CertificateRequest).to receive(:new).with("myname").and_return(@request)

      key = double('key', :public_key => double("public_key"), :content => "mycontent")

      expect(@host).to receive(:key).twice.and_return(nil, key)
      expect(@host).to receive(:generate_key).and_return(key)

      allow(@request).to receive(:generate)
      allow(Puppet::SSL::CertificateRequest.indirection).to receive(:save)

      @host.generate_certificate_request
    end

    it "should be able to generate and save a new request using the private key" do
      expect(Puppet::SSL::CertificateRequest).to receive(:new).with("myname").and_return(@request)

      key = double('key', :public_key => double("public_key"), :content => "mycontent")
      allow(@host).to receive(:key).and_return(key)
      expect(@request).to receive(:generate).with("mycontent", {})
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:save).with(@request)

      expect(@host.generate_certificate_request).to be_truthy
      expect(@host.certificate_request).to equal(@request)
    end

    it "should return any previously found request without requerying" do
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("myname").and_return(@request).once

      expect(@host.certificate_request).to equal(@request)
      expect(@host.certificate_request).to equal(@request)
    end

    it "should not keep its certificate request in memory if the request cannot be saved" do
      expect(Puppet::SSL::CertificateRequest).to receive(:new).with("myname").and_return(@request)

      key = double('key', :public_key => double("public_key"), :content => "mycontent")
      allow(@host).to receive(:key).and_return(key)
      allow(@request).to receive(:generate)
      allow(@request).to receive(:name).and_return("myname")
      terminus = double('terminus')
      allow(terminus).to receive(:validate)
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:prepare).and_return(terminus)
      expect(terminus).to receive(:save) do |req|
        expect(req.instance).to eq(@request)
        expect(req.key).to eq("myname")
      end.and_raise("eh")

      expect { @host.generate_certificate_request }.to raise_error(RuntimeError)

      expect(@host.instance_eval { @certificate_request }).to be_nil
    end
  end

  describe "when managing its certificate" do
    before do
      @realcert = double('certificate')
      @cert = double('cert', :content => @realcert)
      allow(@host).to receive(:key).and_return(double("key"))
      allow(@host).to receive(:validate_certificate_with_key)
    end

    it "should find the CA certificate if it does not have a certificate" do
      expect(Puppet::SSL::Certificate.indirection).to receive(:find).with(Puppet::SSL::CA_NAME, :fail_on_404 => true).and_return(double("cacert"))
      allow(Puppet::SSL::Certificate.indirection).to receive(:find).with("myname").and_return(@cert)
      @host.certificate
    end

    it "should not find the CA certificate if it is the CA host" do
      expect(@host).to receive(:ca?).and_return(true)
      allow(Puppet::SSL::Certificate.indirection).to receive(:find)
      expect(Puppet::SSL::Certificate.indirection).not_to receive(:find).with(Puppet::SSL::CA_NAME, :fail_on_404 => true)

      @host.certificate
    end

    it "should return nil if it cannot find a CA certificate" do
      expect(Puppet::SSL::Certificate.indirection).to receive(:find).with(Puppet::SSL::CA_NAME, :fail_on_404 => true).and_return(nil)
      expect(Puppet::SSL::Certificate.indirection).not_to receive(:find).with("myname")

      expect(@host.certificate).to be_nil
    end

    it "should find the key if it does not have one" do
      allow(Puppet::SSL::Certificate.indirection).to receive(:find)
      expect(@host).to receive(:key).and_return(double("key"))
      @host.certificate
    end

    it "should generate the key if one cannot be found" do
      allow(Puppet::SSL::Certificate.indirection).to receive(:find)
      expect(@host).to receive(:key).and_return(nil)
      expect(@host).to receive(:generate_key)
      @host.certificate
    end

    it "should find the certificate in the Certificate class and return the Puppet certificate instance" do
      expect(Puppet::SSL::Certificate.indirection).to receive(:find).with(Puppet::SSL::CA_NAME, :fail_on_404 => true).and_return(double("cacert"))
      expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("myname").and_return(@cert)
      expect(@host.certificate).to equal(@cert)
    end

    it "should return any previously found certificate" do
      expect(Puppet::SSL::Certificate.indirection).to receive(:find).with(Puppet::SSL::CA_NAME, :fail_on_404 => true).and_return(double("cacert"))
      expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("myname").and_return(@cert).once

      expect(@host.certificate).to equal(@cert)
      expect(@host.certificate).to equal(@cert)
    end
  end

  it "should have a method for listing certificate hosts" do
    expect(Puppet::SSL::Host).to respond_to(:search)
  end

  describe "when listing certificate hosts" do
    it "should default to listing all clients with any file types" do
      expect(Puppet::SSL::Key.indirection).to receive(:search).and_return([])
      expect(Puppet::SSL::Certificate.indirection).to receive(:search).and_return([])
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:search).and_return([])
      Puppet::SSL::Host.search
    end

    it "should be able to list only clients with a key" do
      expect(Puppet::SSL::Key.indirection).to receive(:search).and_return([])
      expect(Puppet::SSL::Certificate.indirection).not_to receive(:search)
      expect(Puppet::SSL::CertificateRequest.indirection).not_to receive(:search)
      Puppet::SSL::Host.search :for => Puppet::SSL::Key
    end

    it "should be able to list only clients with a certificate" do
      expect(Puppet::SSL::Key.indirection).not_to receive(:search)
      expect(Puppet::SSL::Certificate.indirection).to receive(:search).and_return([])
      expect(Puppet::SSL::CertificateRequest.indirection).not_to receive(:search)
      Puppet::SSL::Host.search :for => Puppet::SSL::Certificate
    end

    it "should be able to list only clients with a certificate request" do
      expect(Puppet::SSL::Key.indirection).not_to receive(:search)
      expect(Puppet::SSL::Certificate.indirection).not_to receive(:search)
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:search).and_return([])
      Puppet::SSL::Host.search :for => Puppet::SSL::CertificateRequest
    end

    it "should return a Host instance created with the name of each found instance" do
      key  = double('key',  :name => "key",  :to_ary => nil)
      cert = double('cert', :name => "cert", :to_ary => nil)
      csr  = double('csr',  :name => "csr",  :to_ary => nil)

      expect(Puppet::SSL::Key.indirection).to receive(:search).and_return([key])
      expect(Puppet::SSL::Certificate.indirection).to receive(:search).and_return([cert])
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:search).and_return([csr])

      returned = []
      %w{key cert csr}.each do |name|
        result = double(name)
        returned << result
        expect(Puppet::SSL::Host).to receive(:new).with(name).and_return(result)
      end

      result = Puppet::SSL::Host.search
      returned.each do |r|
        expect(result).to be_include(r)
      end
    end
  end

  it "should have a method for generating all necessary files" do
    expect(Puppet::SSL::Host.new("me")).to respond_to(:generate)
  end

  describe "when generating files" do
    before do
      @host = Puppet::SSL::Host.new("me")
      allow(@host).to receive(:generate_key)
      allow(@host).to receive(:generate_certificate_request)
    end

    it "should generate a key if one is not present" do
      allow(@host).to receive(:key).and_return nil
      expect(@host).to receive(:generate_key)

      @host.generate
    end

    it "should generate a certificate request if one is not present" do
      expect(@host).to receive(:certificate_request).and_return nil
      expect(@host).to receive(:generate_certificate_request)

      @host.generate
    end

    describe "and it can create a certificate authority" do
      before do
        @ca = double('ca')
        allow(Puppet::SSL::CertificateAuthority).to receive(:instance).and_return(@ca)
      end

      it "should use the CA to sign its certificate request if it does not have a certificate" do
        expect(@host).to receive(:certificate).and_return(nil)

        expect(@ca).to receive(:sign).with(@host.name, {allow_dns_alt_names: true})

        @host.generate
      end
    end

    describe "and it cannot create a certificate authority" do
      before do
        allow(Puppet::SSL::CertificateAuthority).to receive(:instance).and_return(nil)
      end

      it "should seek its certificate" do
        expect(@host).to receive(:certificate)

        @host.generate
      end
    end
  end

  it "should have a method for creating an SSL store" do
    expect(Puppet::SSL::Host.new("me")).to respond_to(:ssl_store)
  end

  it "should always return the same store" do
    host = Puppet::SSL::Host.new("foo")
    store = double(
      'store',
      :purpose= => nil,
      :add_file => nil,
    )
    expect(OpenSSL::X509::Store).to receive(:new).and_return(store)
    expect(host.ssl_store).to equal(host.ssl_store)
  end

  describe "when creating an SSL store" do
    before do
      @host = Puppet::SSL::Host.new("me")
      @store = double(
        'store',
        :purpose= => nil,
        :add_file => nil,
        :add_crl  => nil,
        :flags=   => nil,
      )
      allow(OpenSSL::X509::Store).to receive(:new).and_return(@store)

      Puppet[:localcacert] = "ssl_host_testing"

      allow(Puppet::SSL::CertificateRevocationList.indirection).to receive(:find).and_return(nil)
    end

    it "should accept a purpose" do
      expect(@store).to receive(:purpose=).with("my special purpose")
      @host.ssl_store("my special purpose")
    end

    it "should default to OpenSSL::X509::PURPOSE_ANY as the purpose" do
      expect(@store).to receive(:purpose=).with(OpenSSL::X509::PURPOSE_ANY)
      @host.ssl_store
    end

    it "should add the local CA cert file" do
      Puppet[:localcacert] = "/ca/cert/file"
      expect(@store).to receive(:add_file).with(Puppet[:localcacert])
      @host.ssl_store
    end

    describe "and a CRL is available" do
      before do
        @crl = double('crl', :content => "real_crl")
        allow(Puppet::SSL::CertificateRevocationList.indirection).to receive(:find).and_return(@crl)
      end

      [true, 'chain'].each do |crl_setting|
        describe "and 'certificate_revocation' is #{crl_setting}" do
          before do
            Puppet[:certificate_revocation] = crl_setting
          end

          it "should add the CRL" do
            expect(@store).to receive(:add_crl).with("real_crl")
            @host.ssl_store
          end

          it "should set the flags to OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK" do
            expect(@store).to receive(:flags=).with(OpenSSL::X509::V_FLAG_CRL_CHECK_ALL | OpenSSL::X509::V_FLAG_CRL_CHECK)
            @host.ssl_store
          end
        end
      end

      describe "and 'certificate_revocation' is leaf" do
        before do
          Puppet[:certificate_revocation] = 'leaf'
        end

        it "should add the CRL" do
          expect(@store).to receive(:add_crl).with("real_crl")
          @host.ssl_store
        end

        it "should set the flags to OpenSSL::X509::V_FLAG_CRL_CHECK" do
          expect(@store).to receive(:flags=).with(OpenSSL::X509::V_FLAG_CRL_CHECK)
          @host.ssl_store
        end
      end

      describe "and 'certificate_revocation' is false" do
        before do
          Puppet[:certificate_revocation] = false
        end

        it "should not add the CRL" do
          expect(@store).not_to receive(:add_crl)
          @host.ssl_store
        end

        it "should not set the flags" do
          expect(@store).not_to receive(:flags=)
          @host.ssl_store
        end
      end
    end
  end

  describe "when waiting for a cert" do
    before do
      @host = Puppet::SSL::Host.new("me")
    end

    it "should generate its certificate request and attempt to read the certificate again if no certificate is found" do
      expect(@host).to receive(:certificate).twice.and_return(nil, "foo")
      expect(@host).to receive(:generate)
      @host.wait_for_cert(1)
    end

    it "should catch and log errors during CSR saving" do
      expect(@host).to receive(:certificate).twice.and_return(nil, "foo")
      times_generate_called = 0
      expect(@host).to receive(:generate) do
        times_generate_called += 1
        raise RuntimeError if times_generate_called == 1
        nil
      end
      allow(@host).to receive(:sleep)
      @host.wait_for_cert(1)
    end

    it "should sleep and retry after failures saving the CSR if waitforcert is enabled" do
      expect(@host).to receive(:certificate).twice.and_return(nil, "foo")
      times_generate_called = 0
      expect(@host).to receive(:generate) do
        times_generate_called += 1
        raise RuntimeError if times_generate_called == 1
        nil
      end
      expect(@host).to receive(:sleep).with(1)
      @host.wait_for_cert(1)
    end

    it "should exit after failures saving the CSR of waitforcert is disabled" do
      expect(@host).to receive(:certificate).and_return(nil)
      expect(@host).to receive(:generate).and_raise(RuntimeError)
      expect(@host).to receive(:puts)
      expect { @host.wait_for_cert(0) }.to exit_with 1
    end

    it "should exit if the wait time is 0 and it can neither find nor retrieve a certificate" do
      allow(@host).to receive(:certificate).and_return(nil)
      expect(@host).to receive(:generate)
      expect(@host).to receive(:puts)
      expect { @host.wait_for_cert(0) }.to exit_with 1
    end

    it "should sleep for the specified amount of time if no certificate is found after generating its certificate request" do
      expect(@host).to receive(:certificate).exactly(3).times().and_return(nil, nil, "foo")
      expect(@host).to receive(:generate)

      expect(@host).to receive(:sleep).with(1)

      @host.wait_for_cert(1)
    end

    it "should catch and log exceptions during certificate retrieval" do
      times_certificate_called = 0
      expect(@host).to receive(:certificate) do
        times_certificate_called += 1
        if times_certificate_called == 1
          return nil
        elsif times_certificate_called == 2
          raise RuntimeError
        end
        "foo"
      end.exactly(3).times()
      allow(@host).to receive(:generate)
      allow(@host).to receive(:sleep)

      expect(Puppet).to receive(:err).twice

      @host.wait_for_cert(1)
    end
  end

  describe "when handling JSON", :unless => Puppet.features.microsoft_windows? do
    include PuppetSpec::Files

    before do
      Puppet[:vardir] = tmpdir("ssl_test_vardir")
      Puppet[:ssldir] = tmpdir("ssl_test_ssldir")
      # localcacert is where each client stores the CA certificate
      # cacert is where the master stores the CA certificate
      # Since we need to play the role of both for testing we need them to be the same and exist
      Puppet[:cacert] = Puppet[:localcacert]

      @ca=Puppet::SSL::CertificateAuthority.new
    end

    describe "when converting to JSON" do
      let(:host) do
        Puppet::SSL::Host.new("bazinga")
      end

      let(:json_hash) do
        {
          "fingerprint"   => host.certificate_request.fingerprint,
          "desired_state" => 'requested',
          "name"          => host.name
        }
      end

      it "should be able to identify a host with an unsigned certificate request" do
        host.generate_certificate_request

        result = JSON.parse(Puppet::SSL::Host.new(host.name).to_json)

        base_json_comparison result, json_hash
      end

      it "should validate against the schema" do
        host.generate_certificate_request

        expect(host.to_json).to validate_against('api/schemas/host.json')
      end

      describe "explicit fingerprints" do
        [:SHA1, :SHA256, :SHA512].each do |md|
          it "should include #{md}" do
            mds = md.to_s
            host.generate_certificate_request
            json_hash["fingerprints"] = {}
            json_hash["fingerprints"][mds] = host.certificate_request.fingerprint(md)

            result = JSON.parse(Puppet::SSL::Host.new(host.name).to_json)
            base_json_comparison result, json_hash
            expect(result["fingerprints"][mds]).to eq(json_hash["fingerprints"][mds])
          end
        end
      end

      describe "dns_alt_names" do
        describe "when not specified" do
          it "should include the dns_alt_names associated with the certificate" do
            host.generate_certificate_request
            json_hash["desired_alt_names"] = host.certificate_request.subject_alt_names

            result = JSON.parse(Puppet::SSL::Host.new(host.name).to_json)
            base_json_comparison result, json_hash
            expect(result["dns_alt_names"]).to eq(json_hash["desired_alt_names"])
          end
        end

        [ "",
          "test, alt, names"
        ].each do |alt_names|
          describe "when #{alt_names}" do
            before(:each) do
              host.generate_certificate_request :dns_alt_names => alt_names
            end

            it "should include the dns_alt_names associated with the certificate" do
              json_hash["desired_alt_names"] = host.certificate_request.subject_alt_names

              result = JSON.parse(Puppet::SSL::Host.new(host.name).to_json)
              base_json_comparison result, json_hash
              expect(result["dns_alt_names"]).to eq(json_hash["desired_alt_names"])
            end

            it "should validate against the schema" do
              expect(host.to_json).to validate_against('api/schemas/host.json')
            end
          end
        end
      end

      it "should be able to identify a host with a signed certificate" do
        host.generate_certificate_request
        @ca.sign(host.name)
        json_hash = {
          "fingerprint"          => Puppet::SSL::Certificate.indirection.find(host.name).fingerprint,
          "desired_state"        => 'signed',
          "name"                 => host.name,
        }

        result = JSON.parse(Puppet::SSL::Host.new(host.name).to_json)
        base_json_comparison result, json_hash
      end

      it "should be able to identify a host with a revoked certificate" do
        host.generate_certificate_request
        @ca.sign(host.name)
        @ca.revoke(host.name)
        json_hash["fingerprint"] = Puppet::SSL::Certificate.indirection.find(host.name).fingerprint
        json_hash["desired_state"] = 'revoked'

        result = JSON.parse(Puppet::SSL::Host.new(host.name).to_json)
        base_json_comparison result, json_hash
      end
    end

    describe "when converting from JSON" do
      it "should return a Puppet::SSL::Host object with the specified desired state" do
        host = Puppet::SSL::Host.new("bazinga")
        host.desired_state="signed"
        json_hash = {
          "name"  => host.name,
          "desired_state" => host.desired_state,
        }
        generated_host = Puppet::SSL::Host.from_data_hash(json_hash)
        expect(generated_host.desired_state).to eq(host.desired_state)
        expect(generated_host.name).to eq(host.name)
      end
    end
  end
end
