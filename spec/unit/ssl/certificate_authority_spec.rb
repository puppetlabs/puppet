# encoding: ASCII-8BIT
require 'spec_helper'

require 'puppet/ssl/certificate_authority'

describe Puppet::SSL::CertificateAuthority do
  after do
    Puppet::SSL::CertificateAuthority.instance_variable_set(:@singleton_instance, nil)
  end

  def stub_ca_host
    @key = double('key')
    allow(@key).to receive(:content).and_return("cakey")
    @cacert = double('certificate')
    allow(@cacert).to receive(:content).and_return("cacertificate")

    @host = double('ssl_host', :key => @key, :certificate => @cacert, :name => Puppet::SSL::Host.ca_name)
  end

  it "should have a class method for returning a singleton instance" do
    expect(Puppet::SSL::CertificateAuthority).to respond_to(:instance)
  end

  describe "when finding an existing instance" do
    describe "and the host is a CA host and the run_mode is master" do
      before do
        Puppet[:ca] = true
        allow(Puppet.run_mode).to receive(:master?).and_return(true)

        @ca = double('ca')
        allow(Puppet::SSL::CertificateAuthority).to receive(:new).and_return(@ca)
      end

      it "should return an instance" do
        expect(Puppet::SSL::CertificateAuthority.instance).to equal(@ca)
      end

      it "should always return the same instance" do
        expect(Puppet::SSL::CertificateAuthority.instance).to equal(Puppet::SSL::CertificateAuthority.instance)
      end
    end

    describe "and the host is not a CA host" do
      it "should return nil" do
        Puppet[:ca] = false
        allow(Puppet.run_mode).to receive(:master?).and_return(true)

        expect(Puppet::SSL::CertificateAuthority).not_to receive(:new)
        expect(Puppet::SSL::CertificateAuthority.instance).to be_nil
      end
    end

    describe "and the run_mode is not master" do
      it "should return nil" do
        Puppet[:ca] = true
        allow(Puppet.run_mode).to receive(:master?).and_return(false)

        expect(Puppet::SSL::CertificateAuthority).not_to receive(:new)
        expect(Puppet::SSL::CertificateAuthority.instance).to be_nil
      end
    end
  end

  describe "when initializing" do
    before do
      allow(Puppet.settings).to receive(:use)

      allow_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:setup)
    end

    it "should always set its name to the value of :certname" do
      Puppet[:certname] = "ca_testing"

      expect(Puppet::SSL::CertificateAuthority.new.name).to eq("ca_testing")
    end

    it "should create an SSL::Host instance whose name is the 'ca_name'" do
      expect(Puppet::SSL::Host).to receive(:ca_name).and_return("caname")

      host = double('host')
      expect(Puppet::SSL::Host).to receive(:new).with("caname").and_return(host)

      Puppet::SSL::CertificateAuthority.new
    end

    it "should use the :main, :ca, and :ssl settings sections" do
      expect(Puppet.settings).to receive(:use).with(:main, :ssl, :ca)
      Puppet::SSL::CertificateAuthority.new
    end

    it "should make sure the CA is set up" do
      expect_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:setup)

      Puppet::SSL::CertificateAuthority.new
    end
  end

  describe "when setting itself up" do
    it "should generate the CA certificate if it does not have one" do
      allow(Puppet.settings).to receive(:use)

      host = double('host')
      allow(Puppet::SSL::Host).to receive(:new).and_return(host)

      expect(host).to receive(:certificate).and_return(nil)

      expect_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:generate_ca_certificate)
      Puppet::SSL::CertificateAuthority.new
    end
  end

  describe "when retrieving the certificate revocation list" do
    before do
      allow(Puppet.settings).to receive(:use)
      Puppet[:cacrl] = "/my/crl"

      cert = double("certificate", :content => "real_cert")
      key = double("key", :content => "real_key")
      @host = double('host', :certificate => cert, :name => "hostname", :key => key)

      allow_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:setup)
      @ca = Puppet::SSL::CertificateAuthority.new

      allow(@ca).to receive(:host).and_return(@host)
    end

    it "should return any found CRL instance" do
      crl = double('crl')
      expect(Puppet::SSL::CertificateRevocationList.indirection).to receive(:find).and_return(crl)
      expect(@ca.crl).to equal(crl)
    end

    it "should create, generate, and save a new CRL instance of no CRL can be found" do
      crl = Puppet::SSL::CertificateRevocationList.new("fakename")
      expect(Puppet::SSL::CertificateRevocationList.indirection).to receive(:find).and_return(nil)

      expect(Puppet::SSL::CertificateRevocationList).to receive(:new).and_return(crl)

      expect(crl).to receive(:generate).with(@ca.host.certificate.content, @ca.host.key.content)
      expect(Puppet::SSL::CertificateRevocationList.indirection).to receive(:save).with(crl)

      expect(@ca.crl).to equal(crl)
    end
  end

  describe "when generating a self-signed CA certificate" do
    before do
      allow(Puppet.settings).to receive(:use)

      allow_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:setup)
      allow_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:crl)
      @ca = Puppet::SSL::CertificateAuthority.new

      @host = double('host', :key => double("key"), :name => "hostname", :certificate => double('certificate'))

      allow_any_instance_of(Puppet::SSL::CertificateRequest).to receive(:generate)

      allow(@ca).to receive(:host).and_return(@host)
    end

    it "should create and store a password at :capass" do
      Puppet[:capass] = File.expand_path("/path/to/pass")

      expect(Puppet::FileSystem).to receive(:exist?).with(Puppet[:capass]).and_return(false)

      fh = StringIO.new
      expect(Puppet.settings.setting(:capass)).to receive(:open).with('w:ASCII').and_yield(fh)

      allow(@ca).to receive(:sign)

      @ca.generate_ca_certificate

      expect(fh.string.length).to be > 18
    end

    it "should generate a key if one does not exist" do
      allow(@ca).to receive(:generate_password)
      allow(@ca).to receive(:sign)

      expect(@ca.host).to receive(:key).and_return(nil)
      expect(@ca.host).to receive(:generate_key)

      @ca.generate_ca_certificate
    end

    it "should create and sign a self-signed cert using the CA name" do
      request = double('request')
      expect(Puppet::SSL::CertificateRequest).to receive(:new).with(@ca.host.name).and_return(request)
      expect(request).to receive(:generate).with(@ca.host.key)
      allow(request).to receive(:request_extensions).and_return([])

      expect(@ca).to receive(:sign).with(
        @host.name,
        {
          allow_dns_alt_names: false,
          self_signing_csr: request
        }
      )

      allow(@ca).to receive(:generate_password)

      @ca.generate_ca_certificate
    end

    it "should generate its CRL" do
      allow(@ca).to receive(:generate_password)
      allow(@ca).to receive(:sign)

      expect(@ca.host).to receive(:key).and_return(nil)
      expect(@ca.host).to receive(:generate_key)

      expect(@ca).to receive(:crl)

      @ca.generate_ca_certificate
    end
  end

  describe "when signing" do
    before do
      allow(Puppet.settings).to receive(:use)

      allow_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:password?).and_return(true)

      stub_ca_host

      expect(Puppet::SSL::Host).to receive(:new).with(Puppet::SSL::Host.ca_name).and_return(@host)

      @ca = Puppet::SSL::CertificateAuthority.new

      @name = "myhost"
      @real_cert = double('realcert', :sign => nil)
      @cert = Puppet::SSL::Certificate.new(@name)
      @cert.content = @real_cert

      allow(Puppet::SSL::Certificate).to receive(:new).and_return(@cert)

      allow(Puppet::SSL::Certificate.indirection).to receive(:save)

      # Stub out the factory
      allow(Puppet::SSL::CertificateFactory).to receive(:build).and_return(@cert.content)

      @request_content = double("request content stub", :subject => OpenSSL::X509::Name.new([['CN', @name]]), :public_key => double('public_key'))
      @request = double('request', :name => @name, :request_extensions => [], :subject_alt_names => [], :content => @request_content)
      allow(@request_content).to receive(:verify).and_return(true)

      # And the inventory
      @inventory = double('inventory', :add => nil)
      allow(@ca).to receive(:inventory).and_return(@inventory)

      allow(Puppet::SSL::CertificateRequest.indirection).to receive(:destroy)
    end

    describe "its own certificate" do
      before do
        @serial = 10
        allow(@ca).to receive(:next_serial).and_return(@serial)
      end

      it "should not look up a certificate request for the host" do
        expect(Puppet::SSL::CertificateRequest.indirection).not_to receive(:find)

        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should use a certificate type of :ca" do
        expect(Puppet::SSL::CertificateFactory).to receive(:build).with(:ca, any_args).and_return(@cert.content)
        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should pass the provided CSR as the CSR" do
        expect(Puppet::SSL::CertificateFactory).to receive(:build).with(anything, @request, any_args).and_return(@cert.content)
        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should use the provided CSR's content as the issuer" do
        expect(Puppet::SSL::CertificateFactory).to receive(:build) do |*args|
          expect(args[2].subject.to_s).to eq("/CN=myhost")
        end.and_return(@cert.content)
        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should pass the next serial as the serial number" do
        expect(Puppet::SSL::CertificateFactory).to receive(:build).with(anything, anything, anything, @serial).and_return(@cert.content)
        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should sign the certificate request even if it contains alt names" do
        allow(@request).to receive(:subject_alt_names).and_return(%w[DNS:foo DNS:bar DNS:baz])

        expect do
          @ca.sign(@name, {allow_dns_alt_names: false,
                           self_signing_csr: @request})
        end.not_to raise_error
      end

      it "should save the resulting certificate" do
        expect(Puppet::SSL::Certificate.indirection).to receive(:save).with(@cert)

        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end
    end

    describe "another host's certificate" do
      before do
        @serial = 10
        allow(@ca).to receive(:next_serial).and_return(@serial)

        allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with(@name).and_return(@request)
        allow(Puppet::SSL::CertificateRequest.indirection).to receive(:save)
      end

      it "should use a certificate type of :server" do
        expect(Puppet::SSL::CertificateFactory).to receive(:build).with(:server, any_args).and_return(@cert.content)

        @ca.sign(@name)
      end

      it "should use look up a CSR for the host in the :ca_file terminus" do
        expect(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with(@name).and_return(@request)

        @ca.sign(@name)
      end

      it "should fail if no CSR can be found for the host" do
        expect(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with(@name).and_return(nil)

        expect { @ca.sign(@name) }.to raise_error(ArgumentError)
      end

      it "should fail if an unknown request extension is present" do
        allow(@request).to receive(:request_extensions).and_return([{ "oid"   => "bananas",
                                                                      "value" => "delicious" }])
        expect {
          @ca.sign(@name)
        }.to raise_error(/CSR has request extensions that are not permitted/)
      end

      it "should reject auth extensions" do
        allow(@request).to receive(:request_extensions).and_return([{"oid" => "1.3.6.1.4.1.34380.1.3.1",
                                                                     "value" => "true"},
                                                                    {"oid" => "1.3.6.1.4.1.34380.1.3.13",
                                                                     "value" => "com"}])

        expect {
          @ca.sign(@name)
        }.to raise_error(Puppet::SSL::CertificateAuthority::CertificateSigningError,
                         /CSR '#{@name}' contains authorization extensions (.*?, .*?).*/)
      end

      it "should not fail if the CSR contains auth extensions and they're allowed" do
        allow(@request).to receive(:request_extensions).and_return([{"oid" => "1.3.6.1.4.1.34380.1.3.1",
                                                                     "value" => "true"},
                                                                    {"oid" => "1.3.6.1.4.1.34380.1.3.13",
                                                                     "value" => "com"}])
        expect { @ca.sign(@name, {allow_authorization_extensions: true})}.to_not raise_error
      end

      it "should fail if the CSR contains alt names and they are not expected" do
        allow(@request).to receive(:subject_alt_names).and_return(%w[DNS:foo DNS:bar DNS:baz])

        expect do
          @ca.sign(@name, {allow_dns_alt_names: false})
        end.to raise_error(Puppet::SSL::CertificateAuthority::CertificateSigningError, /CSR '#{@name}' contains subject alternative names \(.*?\), which are disallowed. Use `puppet cert --allow-dns-alt-names sign #{@name}` to sign this request./)
      end

      it "should not fail if the CSR does not contain alt names and they are expected" do
        allow(@request).to receive(:subject_alt_names).and_return([])
        expect { @ca.sign(@name, {allow_dns_alt_names: true}) }.to_not raise_error
      end

      it "should reject alt names by default" do
        allow(@request).to receive(:subject_alt_names).and_return(%w[DNS:foo DNS:bar DNS:baz])

        expect do
          @ca.sign(@name)
        end.to raise_error(Puppet::SSL::CertificateAuthority::CertificateSigningError, /CSR '#{@name}' contains subject alternative names \(.*?\), which are disallowed. Use `puppet cert --allow-dns-alt-names sign #{@name}` to sign this request./)
      end

      it "should use the CA certificate as the issuer" do
        expect(Puppet::SSL::CertificateFactory).to receive(:build).with(anything, anything, @cacert.content, any_args).and_return(@cert.content)
        @ca.sign(@name)
      end

      it "should pass the next serial as the serial number" do
        expect(Puppet::SSL::CertificateFactory).to receive(:build).with(anything, anything, anything, @serial).and_return(@cert.content)
        @ca.sign(@name)
      end

      it "should sign the resulting certificate using its real key and a digest" do
        digest = double('digest')
        expect(OpenSSL::Digest::SHA256).to receive(:new).and_return(digest)

        key = double('key', :content => "real_key")
        allow(@ca.host).to receive(:key).and_return(key)

        expect(@cert.content).to receive(:sign).with("real_key", digest)
        @ca.sign(@name)
      end

      it "should save the resulting certificate" do
        allow(Puppet::SSL::Certificate.indirection).to receive(:save).with(@cert)
        @ca.sign(@name)
      end

      it "should remove the host's certificate request" do
        expect(Puppet::SSL::CertificateRequest.indirection).to receive(:destroy).with(@name)

        @ca.sign(@name)
      end

      it "should check the internal signing policies" do
        expect(@ca).to receive(:check_internal_signing_policies).and_return(true)
        @ca.sign(@name)
      end
    end

    context "#check_internal_signing_policies" do
      before do
        @serial = 10
        allow(@ca).to receive(:next_serial).and_return(@serial)

        allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with(@name).and_return(@request)
        allow(@cert).to receive(:save)
      end

      it "should reject CSRs whose CN doesn't match the name for which we're signing them" do
        # Shorten this so the test doesn't take too long
        Puppet[:keylength] = 1024
        key = Puppet::SSL::Key.new('the_certname')
        key.generate

        csr = Puppet::SSL::CertificateRequest.new('the_certname')
        csr.generate(key)

        expect do
          @ca.check_internal_signing_policies('not_the_certname', csr)
        end.to raise_error(
          Puppet::SSL::CertificateAuthority::CertificateSigningError,
          /common name "the_certname" does not match expected certname "not_the_certname"/
        )
      end

      describe "when validating the CN" do
        before :all do
          Puppet[:keylength] = 1024
          Puppet[:passfile] = '/f00'
          @signing_key = Puppet::SSL::Key.new('my_signing_key')
          @signing_key.generate
        end

        [
         'completely_okay',
         'sure, why not? :)',
         'so+many(things)-are=allowed.',
         'this"is#just&madness%you[see]',
         'and even a (an?) \\!',
         'waltz, nymph, for quick jigs vex bud.',
         '{552c04ca-bb1b-11e1-874b-60334b04494e}'
        ].each do |name|
          it "should accept #{name.inspect}" do
            csr = Puppet::SSL::CertificateRequest.new(name)
            csr.generate(@signing_key)

            @ca.check_internal_signing_policies(name, csr)
          end
        end

        [
         'super/bad',
         "not\neven\tkind\rof",
         "ding\adong\a",
         "hidden\b\b\b\b\b\bmessage",
         "\xE2\x98\x83 :("
        ].each do |name|
          it "should reject #{name.inspect}" do
            # We aren't even allowed to make objects with these names, so let's
            # stub that to simulate an invalid one coming from outside Puppet
            allow(Puppet::SSL::CertificateRequest).to receive(:validate_certname)
            csr = Puppet::SSL::CertificateRequest.new(name)
            csr.generate(@signing_key)

            expect do
              @ca.check_internal_signing_policies(name, csr)
            end.to raise_error(
              Puppet::SSL::CertificateAuthority::CertificateSigningError,
              /subject contains unprintable or non-ASCII characters/
            )
          end
        end
      end

      it "accepts numeric OIDs under the ppRegCertExt subtree" do
        exts = [{ 'oid' => '1.3.6.1.4.1.34380.1.1.1',
                  'value' => '657e4780-4cf5-11e3-8f96-0800200c9a66'}]

        allow(@request).to receive(:request_extensions).and_return(exts)

        expect {
          @ca.check_internal_signing_policies(@name, @request)
        }.to_not raise_error
      end

      it "accepts short name OIDs under the ppRegCertExt subtree" do
        exts = [{ 'oid' => 'pp_uuid',
                  'value' => '657e4780-4cf5-11e3-8f96-0800200c9a66'}]

        allow(@request).to receive(:request_extensions).and_return(exts)

        expect {
          @ca.check_internal_signing_policies(@name, @request)
        }.to_not raise_error
      end

      it "accepts OIDs under the ppPrivCertAttrs subtree" do
        exts = [{ 'oid' => '1.3.6.1.4.1.34380.1.2.1',
                  'value' => 'private extension'}]

        allow(@request).to receive(:request_extensions).and_return(exts)

        expect {
          @ca.check_internal_signing_policies(@name, @request)
        }.to_not raise_error
      end


      it "should reject a critical extension that isn't on the whitelist" do
        allow(@request).to receive(:request_extensions).and_return([{ "oid" => "banana",
                                                                      "value" => "yumm",
                                                                      "critical" => true }])
        expect { @ca.check_internal_signing_policies(@name, @request) }.to raise_error(
          Puppet::SSL::CertificateAuthority::CertificateSigningError,
          /request extensions that are not permitted/
        )
      end

      it "should reject a non-critical extension that isn't on the whitelist" do
        allow(@request).to receive(:request_extensions).and_return([{ "oid" => "peach",
                                                                      "value" => "meh",
                                                                      "critical" => false }])
        expect { @ca.check_internal_signing_policies(@name, @request) }.to raise_error(
          Puppet::SSL::CertificateAuthority::CertificateSigningError,
          /request extensions that are not permitted/
        )
      end

      it "should reject non-whitelist extensions even if a valid extension is present" do
        allow(@request).to receive(:request_extensions).and_return([{ "oid" => "peach",
                                                                      "value" => "meh",
                                                                      "critical" => false },
                                                                    { "oid" => "subjectAltName",
                                                                      "value" => "DNS:foo",
                                                                      "critical" => true }])
        expect { @ca.check_internal_signing_policies(@name, @request) }.to raise_error(
          Puppet::SSL::CertificateAuthority::CertificateSigningError,
          /request extensions that are not permitted/
        )
      end

      it "should reject a subjectAltName for a non-DNS value" do
        allow(@request).to receive(:subject_alt_names).and_return(['DNS:foo', 'email:bar@example.com'])
        expect {
          @ca.check_internal_signing_policies(@name, @request, {allow_dns_alt_names: true})
        }.to raise_error(
          Puppet::SSL::CertificateAuthority::CertificateSigningError,
          /subjectAltName outside the DNS label space/
        )
      end

      it "should allow a subjectAltName if subject matches CA's certname" do
        allow(@request).to receive(:subject_alt_names).and_return(['DNS:foo'])
        Puppet[:certname] = @name

        expect {
          @ca.check_internal_signing_policies(@name, @request, {allow_dns_alt_names: false})
        }.to_not raise_error
      end

      it "should reject a wildcard subject" do
        allow(@request.content).to receive(:subject).
          and_return(OpenSSL::X509::Name.new([["CN", "*.local"]]))

        expect { @ca.check_internal_signing_policies('*.local', @request) }.to raise_error(
          Puppet::SSL::CertificateAuthority::CertificateSigningError,
          /subject contains a wildcard/
        )
      end

      it "should reject a wildcard subjectAltName" do
        allow(@request).to receive(:subject_alt_names).and_return(['DNS:foo', 'DNS:*.bar'])
        expect {
          @ca.check_internal_signing_policies(@name, @request, {allow_dns_alt_names: true})
        }.to raise_error(
          Puppet::SSL::CertificateAuthority::CertificateSigningError,
          /subjectAltName contains a wildcard/
        )
      end
    end

    it "should create a certificate instance with the content set to the newly signed x509 certificate" do
      @serial = 10
      allow(@ca).to receive(:next_serial).and_return(@serial)

      allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with(@name).and_return(@request)
      allow(Puppet::SSL::Certificate.indirection).to receive(:save)
      expect(Puppet::SSL::Certificate).to receive(:new).with(@name).and_return(@cert)

      @ca.sign(@name)
    end

    it "should return the certificate instance" do
      allow(@ca).to receive(:next_serial).and_return(@serial)
      allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with(@name).and_return(@request)
      allow(Puppet::SSL::Certificate.indirection).to receive(:save)
      expect(@ca.sign(@name)).to equal(@cert)
    end

    it "should add the certificate to its inventory" do
      allow(@ca).to receive(:next_serial).and_return(@serial)
      expect(@inventory).to receive(:add).with(@cert)

      allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with(@name).and_return(@request)
      allow(Puppet::SSL::Certificate.indirection).to receive(:save)
      @ca.sign(@name)
    end

    it "should have a method for triggering autosigning of available CSRs" do
      expect(@ca).to respond_to(:autosign)
    end

    describe "when autosigning certificates" do
      let(:csr) { Puppet::SSL::CertificateRequest.new("host") }

      describe "using the autosign setting" do
        let(:autosign) { File.expand_path("/auto/sign") }

        it "should do nothing if autosign is disabled" do
          Puppet[:autosign] = false

          expect(@ca).not_to receive(:sign)
          @ca.autosign(csr)
        end

        it "should do nothing if no autosign.conf exists" do
          Puppet[:autosign] = autosign
          non_existent_file = Puppet::FileSystem::MemoryFile.a_missing_file(autosign)
          Puppet::FileSystem.overlay(non_existent_file) do
            expect(@ca).not_to receive(:sign)
            @ca.autosign(csr)
          end
        end

        describe "and autosign is enabled and the autosign.conf file exists" do
          let(:store) { double('store', :allow => nil, :allowed? => false) }

          before do
            Puppet[:autosign] = autosign
          end

          describe "when creating the AuthStore instance to verify autosigning" do
            it "should create an AuthStore with each line in the configuration file allowed to be autosigned" do
              Puppet::FileSystem.overlay(Puppet::FileSystem::MemoryFile.a_regular_file_containing(autosign, "one\ntwo\n")) do
                allow(Puppet::Network::AuthStore).to receive(:new).and_return(store)

                expect(store).to receive(:allow).with("one")
                expect(store).to receive(:allow).with("two")

                @ca.autosign(csr)
              end
            end

            it "should reparse the autosign configuration on each call" do
              Puppet::FileSystem.overlay(Puppet::FileSystem::MemoryFile.a_regular_file_containing(autosign, "one")) do
                allow(Puppet::Network::AuthStore).to receive(:new).twice.and_return(store)

                @ca.autosign(csr)
                @ca.autosign(csr)
              end
            end

            it "should ignore comments" do
              Puppet::FileSystem.overlay(Puppet::FileSystem::MemoryFile.a_regular_file_containing(autosign, "one\n#two\n")) do
                allow(Puppet::Network::AuthStore).to receive(:new).and_return(store)

                expect(store).to receive(:allow).with("one")

                @ca.autosign(csr)
              end
            end

            it "should ignore blank lines" do
              Puppet::FileSystem.overlay(Puppet::FileSystem::MemoryFile.a_regular_file_containing(autosign, "one\n\n")) do
                allow(Puppet::Network::AuthStore).to receive(:new).and_return(store)

                expect(store).to receive(:allow).with("one")
                @ca.autosign(csr)
              end
            end
          end
        end
      end

      describe "using the autosign command setting" do
        let(:cmd) { File.expand_path('/autosign_cmd') }
        let(:autosign_cmd) { double('autosign_command') }
        let(:autosign_executable) { Puppet::FileSystem::MemoryFile.an_executable(cmd) }

        before do
          Puppet[:autosign] = cmd

          allow(Puppet::SSL::CertificateAuthority::AutosignCommand).to receive(:new).and_return(autosign_cmd)
        end

        it "autosigns the CSR if the autosign command returned true" do
          Puppet::FileSystem.overlay(autosign_executable) do
            expect(autosign_cmd).to receive(:allowed?).with(csr).and_return(true)

            expect(@ca).to receive(:sign).with('host')
            @ca.autosign(csr)
          end
        end

        it "doesn't autosign the CSR if the autosign_command returned false" do
          Puppet::FileSystem.overlay(autosign_executable) do
            expect(autosign_cmd).to receive(:allowed?).with(csr).and_return(false)

            expect(@ca).not_to receive(:sign)
            @ca.autosign(csr)
          end
        end
      end
    end
  end

  describe "when managing certificate clients" do
    before do
      allow(Puppet.settings).to receive(:use)

      allow_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:password?).and_return(true)

      stub_ca_host

      expect(Puppet::SSL::Host).to receive(:new).and_return(@host)
      allow_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:host).and_return(@host)

      @cacert = double('certificate')
      allow(@cacert).to receive(:content).and_return("cacertificate")
      @ca = Puppet::SSL::CertificateAuthority.new
    end

    it "should be able to list waiting certificate requests" do
      req1 = double('req1', :name => "one")
      req2 = double('req2', :name => "two")
      expect(Puppet::SSL::CertificateRequest.indirection).to receive(:search).with("*").and_return([req1, req2])

      expect(@ca.waiting?).to eq(%w{one two})
    end

    it "should delegate removing hosts to the Host class" do
      expect(Puppet::SSL::Host).to receive(:destroy).with("myhost")

      @ca.destroy("myhost")
    end

    it "should be able to verify certificates" do
      expect(@ca).to respond_to(:verify)
    end

    it "should list certificates as the sorted list of all existing signed certificates" do
      cert1 = double('cert1', :name => "cert1")
      cert2 = double('cert2', :name => "cert2")
      expect(Puppet::SSL::Certificate.indirection).to receive(:search).with("*").and_return([cert1, cert2])
      expect(@ca.list).to eq(%w{cert1 cert2})
    end

    it "should list the full certificates" do
      cert1 = double('cert1', :name => "cert1")
      cert2 = double('cert2', :name => "cert2")
      expect(Puppet::SSL::Certificate.indirection).to receive(:search).with("*").and_return([cert1, cert2])
      expect(@ca.list_certificates).to eq([cert1, cert2])
    end

    it "should print a deprecation when using #list_certificates" do
      allow(Puppet::SSL::Certificate.indirection).to receive(:search).with("*").and_return([:foo, :bar])
      expect(Puppet).to receive(:deprecation_warning).with(/list_certificates is deprecated/)
      @ca.list_certificates
    end

    describe "and printing certificates" do
      it "should return nil if the certificate cannot be found" do
        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("myhost").and_return(nil)
        expect(@ca.print("myhost")).to be_nil
      end

      it "should print certificates by calling :to_text on the host's certificate" do
        cert1 = double('cert1', :name => "cert1", :to_text => "mytext")
        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("myhost").and_return(cert1)
        expect(@ca.print("myhost")).to eq("mytext")
      end
    end

    describe "and fingerprinting certificates" do
      before :each do
        @cert = double('cert', :name => "cert", :fingerprint => "DIGEST")
        allow(Puppet::SSL::Certificate.indirection).to receive(:find).with("myhost").and_return(@cert)
        allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("myhost")
      end

      it "should raise an error if the certificate or CSR cannot be found" do
        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("myhost").and_return(nil)
        expect(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("myhost").and_return(nil)
        expect { @ca.fingerprint("myhost") }.to raise_error(ArgumentError, /Could not find a certificate/)
      end

      it "should try to find a CSR if no certificate can be found" do
        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("myhost").and_return(nil)
        expect(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("myhost").and_return(@cert)
        expect(@cert).to receive(:fingerprint)
        @ca.fingerprint("myhost")
      end

      it "should delegate to the certificate fingerprinting" do
        expect(@cert).to receive(:fingerprint)
        @ca.fingerprint("myhost")
      end

      it "should propagate the digest algorithm to the certificate fingerprinting system" do
        expect(@cert).to receive(:fingerprint).with(:digest)
        @ca.fingerprint("myhost", :digest)
      end
    end

    describe "and verifying certificates" do
      let(:cacert) { File.expand_path("/ca/cert") }

      before do
        @store = double('store', :verify => true, :add_file => nil, :purpose= => nil, :add_crl => true, :flags= => nil)

        allow(OpenSSL::X509::Store).to receive(:new).and_return(@store)

        @cert = double('cert', :content => "mycert")
        allow(Puppet::SSL::Certificate.indirection).to receive(:find).and_return(@cert)

        @crl = double('crl', :content => "mycrl")

        allow(@ca).to receive(:crl).and_return(@crl)
      end

      it "should fail if the host's certificate cannot be found" do
        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("me").and_return(nil)

        expect { @ca.verify("me") }.to raise_error(ArgumentError)
      end

      it "should create an SSL Store to verify" do
        expect(OpenSSL::X509::Store).to receive(:new).and_return(@store)

        @ca.verify("me")
      end

      it "should add the CA Certificate to the store" do
        Puppet[:cacert] = cacert
        expect(@store).to receive(:add_file).with(cacert)

        @ca.verify("me")
      end

      it "should add the CRL to the store if the crl is enabled" do
        expect(@store).to receive(:add_crl).with("mycrl")

        @ca.verify("me")
      end

      it "should set the store purpose to OpenSSL::X509::PURPOSE_SSL_CLIENT" do
        @store.expects(:purpose=).with OpenSSL::X509::PURPOSE_SSL_CLIENT

        @ca.verify("me")
      end

      it "should set the store flags to check the crl" do
        expect(@store).to receive(:flags=).with(OpenSSL::X509::V_FLAG_CRL_CHECK_ALL | OpenSSL::X509::V_FLAG_CRL_CHECK)

        @ca.verify("me")
      end

      it "should use the store to verify the certificate" do
        expect(@cert).to receive(:content).and_return("mycert")

        expect(@store).to receive(:verify).with("mycert").and_return(true)

        @ca.verify("me")
      end

      it "should fail if the verification returns false" do
        expect(@cert).to receive(:content).and_return("mycert")

        expect(@store).to receive(:verify).with("mycert").and_return(false)
        expect(@store).to receive(:error)
        expect(@store).to receive(:error_string)

        expect { @ca.verify("me") }.to raise_error(Puppet::SSL::CertificateAuthority::CertificateVerificationError)
      end

      describe "certificate_is_alive?" do
        it "should return false if verification fails" do
          expect(@cert).to receive(:content).and_return("mycert")

          expect(@store).to receive(:verify).with("mycert").and_return(false)

          expect(@ca.certificate_is_alive?(@cert)).to be_falsey
        end

        it "should return true if verification passes" do
          expect(@cert).to receive(:content).and_return("mycert")

          expect(@store).to receive(:verify).with("mycert").and_return(true)

          expect(@ca.certificate_is_alive?(@cert)).to be_truthy
        end

        it "should use a cached instance of the x509 store" do
          allow(OpenSSL::X509::Store).to receive(:new).and_return(@store).once

          expect(@cert).to receive(:content).and_return("mycert")

          expect(@store).to receive(:verify).with("mycert").and_return(true)

          @ca.certificate_is_alive?(@cert)
          @ca.certificate_is_alive?(@cert)
        end

        it "should be deprecated" do
          expect(Puppet).to receive(:deprecation_warning).with(/certificate_is_alive\? is deprecated/)
          @ca.certificate_is_alive?(@cert)
        end
      end
    end

    describe "and revoking certificates" do
      before do
        @crl = double('crl')
        allow(@ca).to receive(:crl).and_return(@crl)

        allow(@ca).to receive(:next_serial).and_return(10)

        @real_cert = double('real_cert', :serial => 15)
        @cert = double('cert', :content => @real_cert)
        allow(Puppet::SSL::Certificate.indirection).to receive(:find).and_return(@cert)
      end

      it "should fail if the certificate revocation list is disabled" do
        allow(@ca).to receive(:crl).and_return(false)

        expect { @ca.revoke('ca_testing') }.to raise_error(ArgumentError)

      end

      it "should delegate the revocation to its CRL" do
        expect(@ca.crl).to receive(:revoke)

        @ca.revoke('host')
      end

      it "should get the serial number from the local certificate if it exists" do
        expect(@ca.crl).to receive(:revoke).with(15, anything)

        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("host").and_return(@cert)

        @ca.revoke('host')
      end

      it "should get the serial number from inventory if no local certificate exists" do
        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("host").and_return(nil)

        expect(@ca.inventory).to receive(:serials).with("host").and_return([16])

        expect(@ca.crl).to receive(:revoke).with(16, anything)
        @ca.revoke('host')
      end

      it "should revoke all serials matching a name" do
        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("host").and_return(nil)

        expect(@ca.inventory).to receive(:serials).with("host").and_return([16, 20, 25])

        expect(@ca.crl).to receive(:revoke).with(16, anything)
        expect(@ca.crl).to receive(:revoke).with(20, anything)
        expect(@ca.crl).to receive(:revoke).with(25, anything)
        @ca.revoke('host')
      end

      it "should raise an error if no certificate match" do
        expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("host").and_return(nil)

        expect(@ca.inventory).to receive(:serials).with("host").and_return([])

        expect(@ca.crl).not_to receive(:revoke)
        expect { @ca.revoke('host') }.to raise_error(ArgumentError, /Could not find a serial number for host/)
      end

      context "revocation by serial number (#16798)" do
        it "revokes when given a lower case hexadecimal formatted string" do
          expect(@ca.crl).to receive(:revoke).with(15, anything)
          expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("0xf").and_return(nil)

          @ca.revoke('0xf')
        end

        it "revokes when given an upper case hexadecimal formatted string" do
          expect(@ca.crl).to receive(:revoke).with(15, anything)
          expect(Puppet::SSL::Certificate.indirection).to receive(:find).with("0xF").and_return(nil)

          @ca.revoke('0xF')
        end

        it "handles very large serial numbers" do
          bighex = '0x4000000000000000000000000000000000000000'
          bighex_int = 365375409332725729550921208179070754913983135744

          expect(@ca.crl).to receive(:revoke).with(bighex_int, anything)
          expect(Puppet::SSL::Certificate.indirection).to receive(:find).with(bighex).and_return(nil)

          @ca.revoke(bighex)
        end
      end
    end

    it "should be able to generate a complete new SSL host" do
      expect(@ca).to respond_to(:generate)
    end
  end
end

require 'puppet/indirector/memory'

module CertificateAuthorityGenerateSpecs
describe "CertificateAuthority.generate" do
  def expect_to_increment_serial_file
    expect(Puppet.settings.setting(:serial)).to receive(:exclusive_open)
  end

  def expect_to_sign_a_cert
    expect_to_increment_serial_file
  end

  def expect_to_write_the_ca_password
    expect(Puppet.settings.setting(:capass)).to receive(:open).with('w:ASCII')
  end

  def expect_ca_initialization
    expect_to_write_the_ca_password
    expect_to_sign_a_cert
  end

  INDIRECTED_CLASSES = [
    Puppet::SSL::Certificate,
    Puppet::SSL::CertificateRequest,
    Puppet::SSL::CertificateRevocationList,
    Puppet::SSL::Key,
  ]

  INDIRECTED_CLASSES.each do |const|
    class const::Memory < Puppet::Indirector::Memory

      # @return Array of all the indirector's values
      #
      # This mirrors Puppet::Indirector::SslFile#search which returns all files
      # in the directory.
      def search(request)
        return @instances.values
      end
    end
  end

  before do
    allow(Puppet::SSL::Inventory).to receive(:new).and_return(double("Inventory", :add => nil))
    INDIRECTED_CLASSES.each { |const| const.indirection.terminus_class = :memory }
  end

  after do
    INDIRECTED_CLASSES.each do |const|
      const.indirection.terminus_class = :file
      const.indirection.termini.clear
    end
  end

  describe "when generating certificates" do
    let(:ca) { Puppet::SSL::CertificateAuthority.new }

    before do
      expect_ca_initialization
    end

    it "should fail if a certificate already exists for the host" do
      cert = Puppet::SSL::Certificate.new('pre.existing')
      Puppet::SSL::Certificate.indirection.save(cert)
      expect { ca.generate(cert.name) }.to raise_error(ArgumentError, /a certificate already exists/i)
    end

    describe "that do not yet exist" do
      let(:cn) { "new.host" }

      def expect_cert_does_not_exist(cn)
        expect( Puppet::SSL::Certificate.indirection.find(cn) ).to be_nil
      end

      before do
        expect_to_sign_a_cert
        expect_cert_does_not_exist(cn)
      end

      it "should return the created certificate" do
        cert = ca.generate(cn)
        expect( cert ).to be_kind_of(Puppet::SSL::Certificate)
        expect( cert.name ).to eq(cn)
      end

      it "should not have any subject_alt_names by default" do
        cert = ca.generate(cn)
        expect( cert.subject_alt_names ).to be_empty
      end

      it "should have subject_alt_names if passed dns_alt_names" do
        cert = ca.generate(cn, :dns_alt_names => 'foo,bar')
        expect( cert.subject_alt_names ).to match_array(["DNS:#{cn}",'DNS:foo','DNS:bar'])
      end

      context "if autosign is false" do
        before do
          Puppet[:autosign] = false
        end

        it "should still generate and explicitly sign the request" do
          cert = nil
          cert = ca.generate(cn)
          expect(cert.name).to eq(cn)
        end
      end

      context "if autosign is true (Redmine #6112)" do
        def run_mode_must_be_master_for_autosign_to_be_attempted
          allow(Puppet).to receive(:run_mode).and_return(Puppet::Util::RunMode[:master])
        end

        before do
          Puppet[:autosign] = true
          run_mode_must_be_master_for_autosign_to_be_attempted
          Puppet::Util::Log.level = :info
        end

        it "should generate a cert without attempting to sign again" do
          cert = ca.generate(cn)
          expect(cert.name).to eq(cn)
          expect(@logs.map(&:message)).to include("Autosigning #{cn}")
        end
      end
    end
  end
end
end
