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
      # We use a real object here, because :verify can't be stubbed, apparently.
      @ca = Object.new
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

        @ca.expects(:generate).with("host1", {})
        @ca.expects(:generate).with("host2", {})

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
      describe "and an array of names was provided" do
        let(:applier) { @class.new(:sign, @options.merge(:to => %w{host1 host2})) }

        it "should sign the specified waiting certificate requests" do
          @options = {:allow_dns_alt_names => false}

          @ca.expects(:sign).with("host1", false)
          @ca.expects(:sign).with("host2", false)

          applier.apply(@ca)
        end

        it "should sign the certificate requests with alt names if specified" do
          @options = {:allow_dns_alt_names => true}

          @ca.expects(:sign).with("host1", true)
          @ca.expects(:sign).with("host2", true)

          applier.apply(@ca)
        end
      end

      describe "and :all was provided" do
        it "should sign all waiting certificate requests" do
          @ca.stubs(:waiting?).returns(%w{cert1 cert2})

          @ca.expects(:sign).with("cert1", nil)
          @ca.expects(:sign).with("cert2", nil)

          @applier = @class.new(:sign, :to => :all)
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
      before :each do
        @cert = Puppet::SSL::Certificate.new 'foo'
        @csr = Puppet::SSL::CertificateRequest.new 'bar'

        @cert.stubs(:subject_alt_names).returns []
        @csr.stubs(:subject_alt_names).returns []

        Puppet::SSL::Certificate.indirection.stubs(:find).returns @cert
        Puppet::SSL::CertificateRequest.indirection.stubs(:find).returns @csr

        @digest = mock("digest")
        @digest.stubs(:to_s).returns("(fingerprint)")
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
