#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

require 'puppet/ssl/host'

describe Puppet::Face[:certificate, '0.0.1'] do
  include PuppetSpec::Files

  let(:ca) { Puppet::SSL::CertificateAuthority.instance }

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ܎

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
    expect(subject).to be_option :ca_location
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

    before :each do
      Puppet[:autosign] = false
    end

    describe "for the current host" do
      let(:hostname) { Puppet[:certname] }

      it "should generate a CSR for this host" do
        subject.generate(hostname, options)

        expect(csr.content.subject.to_s).to eq("/CN=#{Puppet[:certname]}")
        expect(csr.name).to eq(Puppet[:certname])
      end

      it "should add dns_alt_names from the global config if not otherwise specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options)

        expected = %W[DNS:from DNS:the DNS:config DNS:#{hostname}]

        expect(csr.subject_alt_names).to match_array(expected)
      end

      it "should add the provided dns_alt_names if they are specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options.merge(:dns_alt_names => "explicit,alt,#{mixed_utf8}"))

        # CSRs will return subject_alt_names as BINARY strings
        expected = %W[DNS:explicit DNS:alt DNS:#{mixed_utf8.force_encoding(Encoding::BINARY)} DNS:#{hostname}]

        expect(csr.subject_alt_names).to match_array(expected)
      end
    end

    describe "for another host" do
      let(:hostname) { Puppet[:certname] + 'different' }

      it "should generate a CSR for the specified host" do
        subject.generate(hostname, options)

        expect(csr.content.subject.to_s).to eq("/CN=#{hostname}")
        expect(csr.name).to eq(hostname)
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

        expect(csr.subject_alt_names).to be_empty
      end

      it "should add the provided dns_alt_names if they are specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options.merge(:dns_alt_names => 'explicit,alt,names'))

        expected = %W[DNS:explicit DNS:alt DNS:names DNS:#{hostname}]

        expect(csr.subject_alt_names).to match_array(expected)
      end
      
      it "should use the global setting if set by CLI" do
        Puppet.settings.patch_value(:dns_alt_names, 'from,the,cli', :cli)
        
        subject.generate(hostname, options)
        
        expected = %W[DNS:from DNS:the DNS:cli DNS:#{hostname}]
        
        expect(csr.subject_alt_names).to match_array(expected)
      end
      
      it "should generate an error if both set on CLI" do
        Puppet.settings.patch_value(:dns_alt_names, 'from,the,cli', :cli)
        expect do
          subject.generate(hostname, options.merge(:dns_alt_names => 'explicit,alt,names'))
        end.to raise_error ArgumentError, /Can't specify both/ 
      end
    end
  end

  describe "#sign" do
    let(:options) { {:ca_location => 'local'} }
    let(:host) { Puppet::SSL::Host.new(hostname) }
    let(:hostname) { "foobar" }

    it "should sign the certificate request if one is waiting", :unless => Puppet.features.microsoft_windows? do
      subject.generate(hostname, options)

      subject.sign(hostname, options)

      expect(host.certificate_request).to be_nil
      expect(host.certificate).to be_a(Puppet::SSL::Certificate)
      expect(host.state).to eq('signed')
    end

    it "should fail if there is no waiting certificate request" do
      expect do
        subject.sign(hostname, options)
      end.to raise_error(ArgumentError, /Could not find certificate request for #{hostname}/)
    end

    describe "when ca_location is local", :unless => Puppet.features.microsoft_windows? do
      describe "when the request has dns alt names" do
        before :each do
          subject.generate(hostname, options.merge(:dns_alt_names => 'some,alt,names'))
        end

        it "should refuse to sign the request if allow_dns_alt_names is not set" do
          expect do
            subject.sign(hostname, options)
          end.to raise_error(Puppet::SSL::CertificateAuthority::CertificateSigningError,
                             /CSR '#{hostname}' contains subject alternative names \(.*?\), which are disallowed. Use `puppet cert --allow-dns-alt-names sign #{hostname}` to sign this request./i)

          expect(host.state).to eq('requested')
        end

        it "should sign the request if allow_dns_alt_names is set" do
          expect do
            subject.sign(hostname, options.merge(:allow_dns_alt_names => true))
          end.not_to raise_error

          expect(host.state).to eq('signed')
        end
      end

      describe "when the request has no dns alt names" do
        before :each do
          subject.generate(hostname, options)
        end

        it "should sign the request if allow_dns_alt_names is set" do
          expect { subject.sign(hostname, options.merge(:allow_dns_alt_names => true)) }.not_to raise_error

          expect(host.state).to eq('signed')
        end

        it "should sign the request if allow_dns_alt_names is not set" do
          expect { subject.sign(hostname, options) }.not_to raise_error

          expect(host.state).to eq('signed')
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
