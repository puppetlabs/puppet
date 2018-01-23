#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/certificate_authority'

shared_examples_for "a normal interface method" do
  it "should call the method on the CA for each host specified if an array was provided" do
    @ca.expects(@method).with("host1")
    @ca.expects(@method).with("host2")

    @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, :to => %w{host1 host2})

    @applier.apply(@ca)
  end

  it "should call the method on the CA for all existing certificates if :all was provided" do
    @ca.expects(:list).returns %w{host1 host2}

    @ca.expects(@method).with("host1")
    @ca.expects(@method).with("host2")

    @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, :to => :all)

    @applier.apply(@ca)
  end
end

shared_examples_for "a destructive interface method" do
  it "calls the method on the CA for each host specified if an array was provided" do
    @ca.expects(@method).with("host1")
    @ca.expects(@method).with("host2")

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
      @ca = mock
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

        @ca.expects(:generate).with() {|*args| args.first == "host1" }
        @ca.expects(:generate).with() {|*args| args.first == "host2" }

        @applier.apply(@ca)
      end
    end

    describe ":verify" do
      before { @method = :verify }
      it_should_behave_like "a normal interface method"
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
          Puppet::SSL::CertificateRequest.indirection.stubs(:find).with("csr1").returns @csr1

          @ca.stubs(:waiting?).returns(%w{csr1})
          @ca.stubs(:check_internal_signing_policies).returns(true)
        end

        it "should prompt before signing cert" do
          @applier = @class.new(:sign, :to => :all, :interactive => true)
          @applier.stubs(:format_host).returns("(host info)")

          @applier.expects(:puts).
            with("Signing Certificate Request for:\n(host info)")

          STDOUT.expects(:print).with("Sign Certificate Request? [y/N] ")

          STDIN.stubs(:gets).returns('y')
          @ca.expects(:sign).with("csr1", {})

          @applier.apply(@ca)
        end

        it "a yes answer can be assumed via options" do
          @applier = @class.new(:sign, :to => :all, :interactive => true, :yes => true)
          @applier.stubs(:format_host).returns("(host info)")

          @applier.expects(:puts).
            with("Signing Certificate Request for:\n(host info)")

          STDOUT.expects(:print).with("Sign Certificate Request? [y/N] ")

          @applier.expects(:puts).
            with("Assuming YES from `-y' or `--assume-yes' flag")

          @ca.expects(:sign).with("csr1", {})

          @applier.apply(@ca)
        end
      end

      describe "and an array of names was provided" do
        before do
          Puppet::SSL::CertificateRequest.indirection.stubs(:find).with("host1").returns @csr1
          Puppet::SSL::CertificateRequest.indirection.stubs(:find).with("host2").returns @csr1
        end

        let(:applier) { @class.new(:sign, @options.merge(:to => %w{host1 host2})) }

        it "should sign the specified waiting certificate requests" do
          @options = {:allow_dns_alt_names => false}
          applier.stubs(:format_host).returns("")
          applier.stubs(:puts)
          @ca.stubs(:check_internal_signing_policies).returns(true)

          @ca.expects(:sign).with("host1", @options)
          @ca.expects(:sign).with("host2", @options)

          applier.apply(@ca)
        end

        it "should sign the certificate requests with alt names if specified" do
          @options = {:allow_dns_alt_names => true}
          applier.stubs(:format_host).returns("")
          applier.stubs(:puts)
          @ca.stubs(:check_internal_signing_policies).returns(true)

          @ca.expects(:sign).with("host1", @options)
          @ca.expects(:sign).with("host2", @options)

          applier.apply(@ca)
        end
      end

      describe "and :all was provided" do
        it "should sign all waiting certificate requests" do
          @ca.stubs(:waiting?).returns(%w{cert1 cert2})
          Puppet::SSL::CertificateRequest.indirection.stubs(:find).with("cert1").returns @csr1
          Puppet::SSL::CertificateRequest.indirection.stubs(:find).with("cert2").returns @csr1
          @ca.stubs(:check_internal_signing_policies).returns(true)

          @ca.expects(:sign).with("cert1", {})
          @ca.expects(:sign).with("cert2", {})

          @applier = @class.new(:sign, :to => :all)
          @applier.stubs(:format_host).returns("")
          @applier.stubs(:puts)
          @applier.apply(@ca)
        end

        it "should fail if there are no waiting certificate requests" do
          @ca.stubs(:waiting?).returns([])

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

        @cert.stubs(:subject_alt_names).returns signed_alt_names
        @cert.stubs(:custom_extensions).returns custom_exts

        @csr.stubs(:subject_alt_names).returns request_alt_names
        @csr.stubs(:custom_attributes).returns custom_attrs
        @csr.stubs(:request_extensions).returns ext_requests

        Puppet::SSL::Certificate.indirection.stubs(:find).returns @cert
        Puppet::SSL::CertificateRequest.indirection.stubs(:find).returns @csr

        @digest = mock("digest")
        @digest.stubs(:to_s).returns("(fingerprint)")

        @expiration = mock('time')
        @expiration.stubs(:iso8601).returns("(expiration)")
        @cert.stubs(:expiration).returns(@expiration)

        @ca.expects(:waiting?).returns %w{host1 host2 host3}
        @ca.expects(:list).returns(%w{host4 host5 host6}).at_most(1)
        @csr.stubs(:digest).returns @digest
        @cert.stubs(:digest).returns @digest
        @ca.stubs(:verify)
      end

      describe "and an empty array was provided" do
        it "should print all certificate requests" do
          applier = @class.new(:list, :to => [])

          applier.expects(:puts).with(<<-OUTPUT.chomp)
  "host1" (fingerprint)
  "host2" (fingerprint)
  "host3" (fingerprint)
          OUTPUT

          applier.apply(@ca)
        end
      end

      describe "and :all was provided" do
        it "should print a string containing all certificate requests and certificates" do
          @ca.expects(:list).returns %w{host4 host5 host6}
          @ca.stubs(:verify).with("host4").raises(Puppet::SSL::CertificateAuthority::CertificateVerificationError.new(23), "certificate revoked")

          applier = @class.new(:list, :to => :all)

          applier.expects(:puts).with(<<-OUTPUT.chomp)
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
          @ca.expects(:list).returns %w{host4 host5 host6}
          applier = @class.new(:list, :to => :signed)

          applier.expects(:puts).with(<<-OUTPUT.chomp)
+ "host4" (fingerprint)
+ "host5" (fingerprint)
+ "host6" (fingerprint)
          OUTPUT

          applier.apply(@ca)
        end

        it "should include subject alt names if they are on the certificate request" do
          @csr.stubs(:subject_alt_names).returns ["DNS:foo", "DNS:bar"]

          applier = @class.new(:list, :to => ['host1'])

          applier.expects(:puts).with(<<-OUTPUT.chomp)
  "host1" (fingerprint) (alt names: "DNS:foo", "DNS:bar")
          OUTPUT

          applier.apply(@ca)
        end
      end

      describe "and an array of names was provided" do
        it "should print all named hosts" do
          applier = @class.new(:list, :to => %w{host1 host2 host4 host5})

          applier.expects(:puts).with(<<-OUTPUT.chomp)
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
          @ca.unstub(:waiting?)
          @ca.unstub(:list)
          @ca.expects(:waiting?).returns %w{ext3}
          @ca.expects(:list).returns(%w{ext1 ext2}).at_most(1)

          @ca.stubs(:verify).with("ext2").
            raises(Puppet::SSL::CertificateAuthority::CertificateVerificationError.new(23),
                   "certificate revoked")

          Puppet::SSL::Certificate.indirection.stubs(:find).returns @cert
          Puppet::SSL::CertificateRequest.indirection.stubs(:find).returns @csr
        end

        describe "using legacy format" do
          it "should append astrisks to end of line to denote additional information available" do
            applier = @class.new(:list, :to => %w{ext1 ext2 ext3})

            applier.expects(:puts).with(<<-OUTPUT.chomp)
  "ext3" (fingerprint) **
+ "ext1" (fingerprint) (alt names: "DNS:puppet", "DNS:puppet.example.com") **
- "ext2" (fingerprint) (certificate revoked)
              OUTPUT

            applier.apply(@ca)
          end

          it "should append attributes and extensions to end of line when running :verbose" do
            applier = @class.new(:list, :to => %w{ext1 ext2 ext3}, :verbose => true)

            applier.expects(:puts).with(<<-OUTPUT.chomp)
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

            applier.expects(:puts).with(<<-OUTPUT.chomp)
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

            applier.expects(:puts).with(<<-OUTPUT)
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
          @ca.expects(:list).returns %w{host1 host2}

          @applier = @class.new(:print, :to => :all)

          @ca.expects(:print).with("host1").returns "h1"
          @applier.expects(:puts).with "h1"

          @ca.expects(:print).with("host2").returns "h2"
          @applier.expects(:puts).with "h2"

          @applier.apply(@ca)
        end
      end

      describe "and an array of names was provided" do
        it "should print each named certificate if found" do
          @applier = @class.new(:print, :to => %w{host1 host2})

          @ca.expects(:print).with("host1").returns "h1"
          @applier.expects(:puts).with "h1"

          @ca.expects(:print).with("host2").returns "h2"
          @applier.expects(:puts).with "h2"

          @applier.apply(@ca)
        end

        it "should log any named but not found certificates" do
          @applier = @class.new(:print, :to => %w{host1 host2})

          @ca.expects(:print).with("host1").returns "h1"
          @applier.expects(:puts).with "h1"

          @ca.expects(:print).with("host2").returns nil
    
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
        Puppet::SSL::Certificate.indirection.stubs(:find)
        Puppet::SSL::CertificateRequest.indirection.stubs(:find)
        Puppet::SSL::Certificate.indirection.stubs(:find).with('host1').returns(@cert)
        Puppet::SSL::CertificateRequest.indirection.stubs(:find).with('host2').returns(@csr)
      end

      it "should fingerprint with the set digest algorithm" do
        @applier = @class.new(:fingerprint, :to => %w{host1}, :digest => :shaonemillion)
        @cert.expects(:digest).with(:shaonemillion).returns("fingerprint1")

        @applier.expects(:puts).with "host1 fingerprint1"

        @applier.apply(@ca)
      end

      describe "and :all was provided" do
        it "should fingerprint all certificates (including waiting ones)" do
          @ca.expects(:list).returns %w{host1}
          @ca.expects(:waiting?).returns %w{host2}

          @applier = @class.new(:fingerprint, :to => :all)

          @cert.expects(:digest).returns("fingerprint1")
          @applier.expects(:puts).with "host1 fingerprint1"

          @csr.expects(:digest).returns("fingerprint2")
          @applier.expects(:puts).with "host2 fingerprint2"

          @applier.apply(@ca)
        end
      end

      describe "and an array of names was provided" do
        it "should print each named certificate if found" do
          @applier = @class.new(:fingerprint, :to => %w{host1 host2})

          @cert.expects(:digest).returns("fingerprint1")
          @applier.expects(:puts).with "host1 fingerprint1"

          @csr.expects(:digest).returns("fingerprint2")
          @applier.expects(:puts).with "host2 fingerprint2"

          @applier.apply(@ca)
        end
      end
    end
  end
end
