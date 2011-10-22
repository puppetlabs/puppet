#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

require 'puppet/ssl/host'

describe Puppet::Face[:certificate, '0.0.1'] do
  include PuppetSpec::Files

  let(:ca) { Puppet::SSL::CertificateAuthority.instance }

  before :each do
    Puppet[:confdir] = tmpdir('conf')
    Puppet::SSL::CertificateAuthority.stubs(:ca?).returns true

    Puppet::SSL::Host.ca_location = :local

    # We can't cache the CA between tests, because each one has its own SSL dir.
    ca = Puppet::SSL::CertificateAuthority.new
    Puppet::SSL::CertificateAuthority.stubs(:new).returns ca
    Puppet::SSL::CertificateAuthority.stubs(:instance).returns ca
  end

  it "should have a ca-location option" do
    subject.should be_option :ca_location
  end

  it "should set the ca location when invoked" do
    Puppet::SSL::Host.expects(:ca_location=).with(:local)
    ca.expects(:sign).with do |name,options|
      name == "hello, friend"
    end

    subject.sign "hello, friend", :ca_location => :local
  end

  it "(#7059) should set the ca location when an inherited action is invoked" do
    Puppet::SSL::Host.expects(:ca_location=).with(:local)
    subject.indirection.expects(:find)
    subject.find "hello, friend", :ca_location => :local
  end

  it "should validate the option as required" do
    expect do
      subject.find 'hello, friend'
    end.to raise_exception ArgumentError, /required/i
  end

  it "should validate the option as a supported value" do
    expect do
      subject.find 'hello, friend', :ca_location => :foo
    end.to raise_exception ArgumentError, /valid values/i
  end

  describe "#generate" do
    let(:options) { {:ca_location => 'local'} }
    let(:host) { Puppet::SSL::Host.new(hostname) }
    let(:csr) { host.certificate_request }

    describe "for the current host" do
      let(:hostname) { Puppet[:certname] }

      it "should generate a CSR for this host" do
        subject.generate(hostname, options)

        csr.content.subject.to_s.should == "/CN=#{Puppet[:certname]}"
        csr.name.should == Puppet[:certname]
      end

      it "should add dns_alt_names from the global config if not otherwise specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options)

        expected = %W[DNS:from DNS:the DNS:config DNS:#{hostname}]

        csr.subject_alt_names.should =~ expected
      end

      it "should add the provided dns_alt_names if they are specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options.merge(:dns_alt_names => 'explicit,alt,names'))

        expected = %W[DNS:explicit DNS:alt DNS:names DNS:#{hostname}]

        csr.subject_alt_names.should =~ expected
      end
    end

    describe "for another host" do
      let(:hostname) { Puppet[:certname] + 'different' }

      it "should generate a CSR for the specified host" do
        subject.generate(hostname, options)

        csr.content.subject.to_s.should == "/CN=#{hostname}"
        csr.name.should == hostname
      end

      it "should fail if a CSR already exists for the host" do
        subject.generate(hostname, options)

        expect do
          subject.generate(hostname, options)
        end.to raise_error(RuntimeError, /#{hostname} already has a requested certificate; ignoring certificate request/)
      end

      it "should add not dns_alt_names from the config file" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options)

        csr.subject_alt_names.should be_empty
      end

      it "should add the provided dns_alt_names if they are specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options.merge(:dns_alt_names => 'explicit,alt,names'))

        expected = %W[DNS:explicit DNS:alt DNS:names DNS:#{hostname}]

        csr.subject_alt_names.should =~ expected
      end
    end
  end

  describe "#sign" do
    let(:options) { {:ca_location => 'local'} }
    let(:host) { Puppet::SSL::Host.new(hostname) }
    let(:hostname) { "foobar" }

    it "should sign the certificate request if one is waiting" do
      subject.generate(hostname, options)

      subject.sign(hostname, options)

      host.certificate_request.should be_nil
      host.certificate.should be_a(Puppet::SSL::Certificate)
      host.state.should == 'signed'
    end

    it "should fail if there is no waiting certificate request" do
      expect do
        subject.sign(hostname, options)
      end.to raise_error(ArgumentError, /Could not find certificate request for #{hostname}/)
    end

    describe "when ca_location is local" do
      describe "when the request has dns alt names" do
        before :each do
          subject.generate(hostname, options.merge(:dns_alt_names => 'some,alt,names'))
        end

        it "should refuse to sign the request if allow_dns_alt_names is not set" do
          expect do
            subject.sign(hostname, options)
          end.to raise_error(Puppet::SSL::CertificateAuthority::CertificateSigningError,
                             /CSR '#{hostname}' contains subject alternative names \(.*?\), which are disallowed. Use `puppet cert --allow-dns-alt-names sign #{hostname}` to sign this request./i)

          host.state.should == 'requested'
        end

        it "should sign the request if allow_dns_alt_names is set" do
          expect do
            subject.sign(hostname, options.merge(:allow_dns_alt_names => true))
          end.not_to raise_error

          host.state.should == 'signed'
        end
      end

      describe "when the request has no dns alt names" do
        before :each do
          subject.generate(hostname, options)
        end

        it "should sign the request if allow_dns_alt_names is set" do
          expect { subject.sign(hostname, options.merge(:allow_dns_alt_names => true)) }.not_to raise_error

          host.state.should == 'signed'
        end

        it "should sign the request if allow_dns_alt_names is not set" do
          expect { subject.sign(hostname, options) }.not_to raise_error

          host.state.should == 'signed'
        end
      end
    end

    describe "when ca_location is remote" do
      let(:options) { {:ca_location => :remote} }
      it "should fail if allow-dns-alt-names is specified" do
        expect do
          subject.sign(hostname, options.merge(:allow_dns_alt_names => true))
        end
      end
    end
  end
end
