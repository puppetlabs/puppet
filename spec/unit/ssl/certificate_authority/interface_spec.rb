require 'spec_helper'

require 'puppet/ssl/certificate_authority'

shared_examples_for "a normal interface method" do
  it "should call the method on the CA for each host specified if an array was provided" do
    expect(@ca).to receive(@method).with("host1")
    expect(@ca).to receive(@method).with("host2")

    @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, :to => %w{host1 host2})

    @applier.apply(@ca)
  end

  it "should call the method on the CA for all existing certificates if :all was provided" do
    expect(@ca).to receive(:list).and_return(%w{host1 host2})

    expect(@ca).to receive(@method).with("host1")
    expect(@ca).to receive(@method).with("host2")

    @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, :to => :all)

    @applier.apply(@ca)
  end
end

shared_examples_for "a destructive interface method" do
  it "calls the method on the CA for each host specified if an array was provided" do
    expect(@ca).to receive(@method).with("host1")
    expect(@ca).to receive(@method).with("host2")

    @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, :to => %w{host1 host2})

    @applier.apply(@ca)
  end

  it "raises an error if :all was provided" do
    @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, :to => :all)

    expect {
      @applier.apply(@ca)
    }.to raise_error(ArgumentError, /Refusing to #{@method} all certs/)
  end

  it "raises an error if :signed was provided" do
    @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, :to => :signed)

    expect {
      @applier.apply(@ca)
    }.to raise_error(ArgumentError, /Refusing to #{@method} all signed certs/)
  end
end

describe Puppet::SSL::CertificateAuthority::Interface do
  before do
    @class = Puppet::SSL::CertificateAuthority::Interface
  end

  describe "when initializing" do
    it "should set its method using its settor" do
      instance = @class.new(:generate, :to => :all)
      expect(instance.method).to eq(:generate)
    end

    it "should set its subjects using the settor" do
      instance = @class.new(:generate, :to => :all)
      expect(instance.subjects).to eq(:all)
    end

    it "should set the digest if given" do
      interface = @class.new(:generate, :to => :all, :digest => :digest)
      expect(interface.digest).to eq(:digest)
    end
  end

  describe "when setting the method" do
    it "should set the method" do
      instance = @class.new(:generate, :to => :all)
      instance.method = :list

      expect(instance.method).to eq(:list)
    end

    it "should fail if the method isn't a member of the INTERFACE_METHODS array" do
      expect { @class.new(:thing, :to => :all) }.to raise_error(ArgumentError, /Invalid method thing to apply/)
    end
  end

  describe "when setting the subjects" do
    it "should set the subjects" do
      instance = @class.new(:generate, :to => :all)
      instance.subjects = :signed

      expect(instance.subjects).to eq(:signed)
    end

    it "should fail if the subjects setting isn't :all or an array" do
      expect { @class.new(:generate, :to => "other") }.to raise_error(ArgumentError, /Subjects must be an array or :all; not other/)
    end
  end

  it "should have a method for triggering the application" do
    expect(@class.new(:generate, :to => :all)).to respond_to(:apply)
  end

  describe "when applying" do
    before do
      # We use a real object here, because :verify can't be stubbed, apparently.
      @ca = double()
    end

    describe "with an empty array specified and the method is not list" do
      it "should fail" do
        @applier = @class.new(:sign, :to => [])
        expect { @applier.apply(@ca) }.to raise_error(ArgumentError)
      end
    end

    describe ":generate" do
      it "should fail if :all was specified" do
        @applier = @class.new(:generate, :to => :all)
        expect { @applier.apply(@ca) }.to raise_error(ArgumentError)
      end

      it "should call :generate on the CA for each host specified" do
        @applier = @class.new(:generate, :to => %w{host1 host2})

        expect(@ca).to receive(:generate).with("host1", any_args)
        expect(@ca).to receive(:generate).with("host2", any_args)

        @applier.apply(@ca)
      end
    end

    describe ":verify" do
      before { @method = :verify }
      #it_should_behave_like "a normal interface method"

      it "should call the method on the CA for each host specified if an array was provided" do
        # LAK:NOTE Mocha apparently doesn't allow you to mock :verify, but I'm confident this works in real life.
      end

      it "should call the method on the CA for all existing certificates if :all was provided" do
        # LAK:NOTE Mocha apparently doesn't allow you to mock :verify, but I'm confident this works in real life.
      end
    end

    describe ":destroy" do
      before { @method = :destroy }
      it_should_behave_like "a destructive interface method"
    end

    describe ":revoke" do
      before { @method = :revoke }
      it_should_behave_like "a destructive interface method"
    end

    describe ":sign" do
      before do
        @csr1 = Puppet::SSL::CertificateRequest.new 'baz'
      end

      describe "when run in interactive mode" do
        before do
          allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("csr1").and_return(@csr1)

          allow(@ca).to receive(:waiting?).and_return(%w{csr1})
          allow(@ca).to receive(:check_internal_signing_policies).and_return(true)
        end

        it "should prompt before signing cert" do
          @applier = @class.new(:sign, :to => :all, :interactive => true)
          allow(@applier).to receive(:format_host).and_return("(host info)")

          expect(@applier).to receive(:puts).
            with("Signing Certificate Request for:\n(host info)")

          expect(STDOUT).to receive(:print).with("Sign Certificate Request? [y/N] ")

          allow(STDIN).to receive(:gets).and_return('y')
          expect(@ca).to receive(:sign).with("csr1", {})

          @applier.apply(@ca)
        end

        it "a yes answer can be assumed via options" do
          @applier = @class.new(:sign, :to => :all, :interactive => true, :yes => true)
          allow(@applier).to receive(:format_host).and_return("(host info)")

          expect(@applier).to receive(:puts).
            with("Signing Certificate Request for:\n(host info)")

          expect(STDOUT).to receive(:print).with("Sign Certificate Request? [y/N] ")

          expect(@applier).to receive(:puts).
            with("Assuming YES from `-y' or `--assume-yes' flag")

          expect(@ca).to receive(:sign).with("csr1", {})

          @applier.apply(@ca)
        end
      end

      describe "and an array of names was provided" do
        before do
          allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("host1").and_return(@csr1)
          allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("host2").and_return(@csr1)
        end

        let(:applier) { @class.new(:sign, @options.merge(:to => %w{host1 host2})) }

        it "should sign the specified waiting certificate requests" do
          @options = {:allow_dns_alt_names => false}
          allow(applier).to receive(:format_host).and_return("")
          allow(applier).to receive(:puts)
          allow(@ca).to receive(:check_internal_signing_policies).and_return(true)

          expect(@ca).to receive(:sign).with("host1", @options)
          expect(@ca).to receive(:sign).with("host2", @options)

          applier.apply(@ca)
        end

        it "should sign the certificate requests with alt names if specified" do
          @options = {:allow_dns_alt_names => true}
          allow(applier).to receive(:format_host).and_return("")
          allow(applier).to receive(:puts)
          allow(@ca).to receive(:check_internal_signing_policies).and_return(true)

          expect(@ca).to receive(:sign).with("host1", @options)
          expect(@ca).to receive(:sign).with("host2", @options)

          applier.apply(@ca)
        end
      end

      describe "and :all was provided" do
        it "should sign all waiting certificate requests" do
          allow(@ca).to receive(:waiting?).and_return(%w{cert1 cert2})
          allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("cert1").and_return(@csr1)
          allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with("cert2").and_return(@csr1)
          allow(@ca).to receive(:check_internal_signing_policies).and_return(true)

          expect(@ca).to receive(:sign).with("cert1", {})
          expect(@ca).to receive(:sign).with("cert2", {})

          @applier = @class.new(:sign, :to => :all)
          allow(@applier).to receive(:format_host).and_return("")
          allow(@applier).to receive(:puts)
          @applier.apply(@ca)
        end

        it "should fail if there are no waiting certificate requests" do
          allow(@ca).to receive(:waiting?).and_return([])

          @applier = @class.new(:sign, :to => :all)
          expect { @applier.apply(@ca) }.to raise_error(Puppet::SSL::CertificateAuthority::Interface::InterfaceError)
        end
      end
    end

    describe ":list" do
      let(:signed_alt_names) { [] }
      let(:request_alt_names) { [] }
      let(:custom_attrs) { [] }
      let(:ext_requests) { [] }
      let(:custom_exts) { [] }

      before :each do
        @cert = Puppet::SSL::Certificate.new 'foo'
        @csr = Puppet::SSL::CertificateRequest.new 'bar'

        allow(@cert).to receive(:subject_alt_names).and_return(signed_alt_names)
        allow(@cert).to receive(:custom_extensions).and_return(custom_exts)

        allow(@csr).to receive(:subject_alt_names).and_return(request_alt_names)
        allow(@csr).to receive(:custom_attributes).and_return(custom_attrs)
        allow(@csr).to receive(:request_extensions).and_return(ext_requests)

        allow(Puppet::SSL::Certificate.indirection).to receive(:find).and_return(@cert)
        allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).and_return(@csr)

        @digest = double("digest")
        allow(@digest).to receive(:to_s).and_return("(fingerprint)")

        @expiration = double('time')
        allow(@expiration).to receive(:iso8601).and_return("(expiration)")
        allow(@cert).to receive(:expiration).and_return(@expiration)

        allow(@csr).to receive(:digest).and_return(@digest)
        allow(@cert).to receive(:digest).and_return(@digest)
        allow(@ca).to receive(:verify)
      end

      describe "and an empty array was provided" do
        it "should print all certificate requests" do
        expect(@ca).to receive(:waiting?).and_return(%w{host1 host2 host3})
        applier = @class.new(:list, :to => [])

          expect(applier).to receive(:puts).with(<<-OUTPUT.chomp)
  "host1" (fingerprint)
  "host2" (fingerprint)
  "host3" (fingerprint)
          OUTPUT

          applier.apply(@ca)
        end
      end

      describe "and :all was provided" do
        it "should print a string containing all certificate requests and certificates" do
          expect(@ca).to receive(:waiting?).and_return(%w{host1 host2 host3})
          expect(@ca).to receive(:list).and_return(%w{host4 host5 host6})
          allow(@ca).to receive(:verify).with("host4").and_raise(Puppet::SSL::CertificateAuthority::CertificateVerificationError.new(23), "certificate revoked")

          applier = @class.new(:list, :to => :all)

          expect(applier).to receive(:puts).with(<<-OUTPUT.chomp)
  "host1" (fingerprint)
  "host2" (fingerprint)
  "host3" (fingerprint)
+ "host5" (fingerprint)
+ "host6" (fingerprint)
- "host4" (fingerprint) (certificate revoked)
          OUTPUT

          applier.apply(@ca)
        end
      end

      describe "and :signed was provided" do
        it "should print a string containing all signed certificate requests and certificates" do
          expect(@ca).to receive(:waiting?).and_return(%w{host1 host2 host3})
          expect(@ca).to receive(:list).and_return(%w{host4 host5 host6})
          applier = @class.new(:list, :to => :signed)

          expect(applier).to receive(:puts).with(<<-OUTPUT.chomp)
+ "host4" (fingerprint)
+ "host5" (fingerprint)
+ "host6" (fingerprint)
          OUTPUT

          applier.apply(@ca)
        end

        it "should include subject alt names if they are on the certificate request" do
          expect(@ca).to receive(:waiting?).and_return(%w{host1 host2 host3})
          expect(@ca).to receive(:list).and_return(%w{host4 host5 host6}).at_most(:once)
          allow(@csr).to receive(:subject_alt_names).and_return(["DNS:foo", "DNS:bar"])

          applier = @class.new(:list, :to => ['host1'])

          expect(applier).to receive(:puts).with(<<-OUTPUT.chomp)
  "host1" (fingerprint) (alt names: "DNS:foo", "DNS:bar")
          OUTPUT

          applier.apply(@ca)
        end
      end

      describe "and an array of names was provided" do
        it "should print all named hosts" do
          expect(@ca).to receive(:waiting?).and_return(%w{host1 host2 host3})
          expect(@ca).to receive(:list).and_return(%w{host4 host5 host6}).at_most(:once)
          applier = @class.new(:list, :to => %w{host1 host2 host4 host5})

          expect(applier).to receive(:puts).with(<<-OUTPUT.chomp)
  "host1" (fingerprint)
  "host2" (fingerprint)
+ "host4" (fingerprint)
+ "host5" (fingerprint)
            OUTPUT

          applier.apply(@ca)
        end
      end

      describe "with custom attrbutes and extensions" do
        let(:custom_attrs) { [{'oid' => 'customAttr', 'value' => 'attrValue'}] }
        let(:ext_requests) { [{'oid' => 'customExt', 'value' => 'reqExtValue'}] }
        let(:custom_exts) {  [{'oid' => 'extName', 'value' => 'extValue'}] }
        let(:signed_alt_names) { ["DNS:puppet", "DNS:puppet.example.com"] }

        before do
          expect(@ca).to receive(:waiting?).and_return(%w{ext3})
          expect(@ca).to receive(:list).and_return(%w{ext1 ext2}).at_most(:once)

          allow(@ca).to receive(:verify).with("ext2").
            and_raise(Puppet::SSL::CertificateAuthority::CertificateVerificationError.new(23),
                      "certificate revoked")

          allow(Puppet::SSL::Certificate.indirection).to receive(:find).and_return(@cert)
          allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).and_return(@csr)
        end

        describe "using legacy format" do
          it "should append astrisks to end of line to denote additional information available" do
            applier = @class.new(:list, :to => %w{ext1 ext2 ext3})

            expect(applier).to receive(:puts).with(<<-OUTPUT.chomp)
  "ext3" (fingerprint) **
+ "ext1" (fingerprint) (alt names: "DNS:puppet", "DNS:puppet.example.com") **
- "ext2" (fingerprint) (certificate revoked)
              OUTPUT

            applier.apply(@ca)
          end

          it "should append attributes and extensions to end of line when running :verbose" do
            applier = @class.new(:list, :to => %w{ext1 ext2 ext3}, :verbose => true)

            expect(applier).to receive(:puts).with(<<-OUTPUT.chomp)
  "ext3" (fingerprint) (customAttr: "attrValue", customExt: "reqExtValue")
+ "ext1" (fingerprint) (expiration) (alt names: "DNS:puppet", "DNS:puppet.example.com", extName: "extValue")
- "ext2" (fingerprint) (certificate revoked)
              OUTPUT

            applier.apply(@ca)
          end
        end

        describe "using line-wise format" do
          it "use the same format as :verbose legacy format" do
            applier = @class.new(:list, :to => %w{ext1 ext2 ext3}, :format => :machine)

            expect(applier).to receive(:puts).with(<<-OUTPUT.chomp)
  "ext3" (fingerprint) (customAttr: "attrValue", customExt: "reqExtValue")
+ "ext1" (fingerprint) (expiration) (alt names: "DNS:puppet", "DNS:puppet.example.com", extName: "extValue")
- "ext2" (fingerprint) (certificate revoked)
              OUTPUT

            applier.apply(@ca)
          end
        end

        describe "using human friendly format" do
          it "should break attributes and extensions to separate lines" do
            applier = @class.new(:list, :to => %w{ext1 ext2 ext3}, :format => :human)

            expect(applier).to receive(:puts).with(<<-OUTPUT)
  "ext3"
  (fingerprint)
    Status: Request Pending
    Extensions:
      customAttr: "attrValue"
      customExt: "reqExtValue"

+ "ext1"
  (fingerprint)
    Status: Signed
    Expiration: (expiration)
    Extensions:
      alt names: "DNS:puppet", "DNS:puppet.example.com"
      extName: "extValue"

- "ext2"
  (fingerprint)
    Status: Invalid - (certificate revoked)
OUTPUT

            applier.apply(@ca)
          end
        end
      end
    end

    describe ":print" do
      describe "and :all was provided" do
        it "should print all certificates" do
          expect(@ca).to receive(:list).and_return(%w{host1 host2})

          @applier = @class.new(:print, :to => :all)

          expect(@ca).to receive(:print).with("host1").and_return("h1")
          expect(@applier).to receive(:puts).with("h1")

          expect(@ca).to receive(:print).with("host2").and_return("h2")
          expect(@applier).to receive(:puts).with("h2")

          @applier.apply(@ca)
        end
      end

      describe "and an array of names was provided" do
        it "should print each named certificate if found" do
          @applier = @class.new(:print, :to => %w{host1 host2})

          expect(@ca).to receive(:print).with("host1").and_return("h1")
          expect(@applier).to receive(:puts).with("h1")

          expect(@ca).to receive(:print).with("host2").and_return("h2")
          expect(@applier).to receive(:puts).with("h2")

          @applier.apply(@ca)
        end

        it "should log any named but not found certificates" do
          @applier = @class.new(:print, :to => %w{host1 host2})

          expect(@ca).to receive(:print).with("host1").and_return("h1")
          expect(@applier).to receive(:puts).with("h1")

          expect(@ca).to receive(:print).with("host2").and_return(nil)
    
	  expect {
            @applier.apply(@ca)
	  }.to raise_error(ArgumentError, /Could not find certificate for host2/)
        end
      end
    end

    describe ":fingerprint" do
      before(:each) do
        @cert = Puppet::SSL::Certificate.new 'foo'
        @csr = Puppet::SSL::CertificateRequest.new 'bar'
        allow(Puppet::SSL::Certificate.indirection).to receive(:find)
        allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find)
        allow(Puppet::SSL::Certificate.indirection).to receive(:find).with('host1').and_return(@cert)
        allow(Puppet::SSL::CertificateRequest.indirection).to receive(:find).with('host2').and_return(@csr)
      end

      it "should fingerprint with the set digest algorithm" do
        @applier = @class.new(:fingerprint, :to => %w{host1}, :digest => :shaonemillion)
        expect(@cert).to receive(:digest).with(:shaonemillion).and_return("fingerprint1")

        expect(@applier).to receive(:puts).with "host1 fingerprint1"

        @applier.apply(@ca)
      end

      describe "and :all was provided" do
        it "should fingerprint all certificates (including waiting ones)" do
          expect(@ca).to receive(:list).and_return(%w{host1})
          expect(@ca).to receive(:waiting?).and_return(%w{host2})

          @applier = @class.new(:fingerprint, :to => :all)

          expect(@cert).to receive(:digest).and_return("fingerprint1")
          expect(@applier).to receive(:puts).with("host1 fingerprint1")

          expect(@csr).to receive(:digest).and_return("fingerprint2")
          expect(@applier).to receive(:puts).with("host2 fingerprint2")

          @applier.apply(@ca)
        end
      end

      describe "and an array of names was provided" do
        it "should print each named certificate if found" do
          @applier = @class.new(:fingerprint, :to => %w{host1 host2})

          expect(@cert).to receive(:digest).and_return("fingerprint1")
          expect(@applier).to receive(:puts).with("host1 fingerprint1")

          expect(@csr).to receive(:digest).and_return("fingerprint2")
          expect(@applier).to receive(:puts).with("host2 fingerprint2")

          @applier.apply(@ca)
        end
      end
    end
  end
end
