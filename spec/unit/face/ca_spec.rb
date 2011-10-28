#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:ca, '0.1.0'], :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  before :each do
    Puppet.run_mode.stubs(:master?).returns(true)
    Puppet[:ca]     = true
    Puppet[:ssldir] = tmpdir("face-ca-ssldir")

    Puppet::SSL::Host.ca_location = :only
    Puppet[:certificate_revocation] = true

    # This is way more intimate than I want to be with the implementation, but
    # there doesn't seem any other way to test this. --daniel 2011-07-18
    Puppet::SSL::CertificateAuthority.stubs(:instance).returns(
        # ...and this actually does the directory creation, etc.
        Puppet::SSL::CertificateAuthority.new
    )
  end

  def make_certs(csr_names, crt_names)
    Array(csr_names).map do |name|
      Puppet::SSL::Host.new(name).generate_certificate_request
    end

    Array(crt_names).map do |name|
      Puppet::SSL::Host.new(name).generate
    end
  end

  context "#verify" do
    let :action do Puppet::Face[:ca, '0.1.0'].get_action(:verify) end

    it "should not explode if there is no certificate" do
      expect {
        subject.verify('random-host').should == {
          :host => 'random-host', :valid => false,
          :error => 'Could not find a certificate for random-host'
        }
      }.should_not raise_error
    end

    it "should not explode if there is only a CSR" do
      make_certs('random-host', [])
      expect {
        subject.verify('random-host').should == {
          :host => 'random-host', :valid => false,
          :error => 'Could not find a certificate for random-host'
        }
      }.should_not raise_error
    end

    it "should verify a signed certificate" do
      make_certs([], 'random-host')
      subject.verify('random-host').should == {
        :host => 'random-host', :valid => true
      }
    end

    it "should not verify a revoked certificate" do
      make_certs([], 'random-host')
      subject.revoke('random-host')

      expect {
        subject.verify('random-host').should == {
          :host => 'random-host', :valid => false,
          :error => 'certificate revoked'
        }
      }.should_not raise_error
    end

    it "should verify a revoked certificate if CRL use was turned off" do
      make_certs([], 'random-host')
      subject.revoke('random-host')

      Puppet[:certificate_revocation] = false
      subject.verify('random-host').should == {
        :host => 'random-host', :valid => true
      }
    end
  end

  context "#fingerprint" do
    let :action do Puppet::Face[:ca, '0.1.0'].get_action(:fingerprint) end

    it "should have a 'digest' option" do
      action.should be_option :digest
    end

    it "should not explode if there is no certificate" do
      expect {
        subject.fingerprint('random-host').should be_nil
      }.should_not raise_error
    end

    it "should fingerprint a CSR" do
      make_certs('random-host', [])
      expect {
        subject.fingerprint('random-host').should =~ /^[0-9A-F:]+$/
      }.should_not raise_error
    end

    it "should fingerprint a certificate" do
      make_certs([], 'random-host')
      subject.fingerprint('random-host').should =~ /^[0-9A-F:]+$/
    end

    %w{md5 MD5 sha1 ShA1 SHA1 RIPEMD160 sha256 sha512}.each do |digest|
      it "should fingerprint with #{digest.inspect}" do
        make_certs([], 'random-host')
        subject.fingerprint('random-host', :digest => digest).should =~ /^[0-9A-F:]+$/
      end

      it "should fingerprint with #{digest.to_sym} as a symbol" do
        make_certs([], 'random-host')
        subject.fingerprint('random-host', :digest => digest.to_sym).
          should =~ /^[0-9A-F:]+$/
      end
    end
  end

  context "#print" do
    let :action do Puppet::Face[:ca, '0.1.0'].get_action(:print) end

    it "should not explode if there is no certificate" do
      expect {
        subject.print('random-host').should be_nil
      }.should_not raise_error
    end

    it "should return nothing if there is only a CSR" do
      make_certs('random-host', [])
      expect {
        subject.print('random-host').should be_nil
      }.should_not raise_error
    end

    it "should return the certificate content if there is a cert" do
      make_certs([], 'random-host')
      text = subject.print('random-host')
      text.should be_an_instance_of String
      text.should =~ /^Certificate:/
      text.should =~ /Issuer: CN=Puppet CA: /
      text.should =~ /Subject: CN=random-host$/
    end
  end

  context "#sign" do
    let :action do Puppet::Face[:ca, '0.1.0'].get_action(:sign) end

    it "should not explode if there is no CSR" do
      expect {
        subject.sign('random-host').
          should == 'Could not find certificate request for random-host'
      }.should_not raise_error
    end

    it "should not explode if there is a signed cert" do
      make_certs([], 'random-host')
      expect {
        subject.sign('random-host').
          should == 'Could not find certificate request for random-host'
      }.should_not raise_error
    end

    it "should sign a CSR if one exists" do
      make_certs('random-host', [])
      subject.sign('random-host').should be_an_instance_of Puppet::SSL::Certificate

      list = subject.list(:signed => true)
      list.length.should == 1
      list.first.name.should == 'random-host'
    end

    describe "when the CSR specifies DNS alt names" do
      let(:host) { Puppet::SSL::Host.new('someone') }

      before :each do
        host.generate_certificate_request(:dns_alt_names => 'some,alt,names')
      end

      it "should sign the CSR if DNS alt names are allowed" do
        subject.sign('someone', :allow_dns_alt_names => true)

        host.certificate.should be_a(Puppet::SSL::Certificate)
      end

      it "should refuse to sign the CSR if DNS alt names are not allowed" do
        certname = 'someone'
        expect do
          subject.sign(certname)
        end.to raise_error(Puppet::SSL::CertificateAuthority::CertificateSigningError, /CSR '#{certname}' contains subject alternative names \(.*\), which are disallowed. Use `puppet cert --allow-dns-alt-names sign #{certname}` to sign this request./i)

        host.certificate.should be_nil
      end
    end
  end

  context "#generate" do
    let :action do Puppet::Face[:ca, '0.1.0'].get_action(:generate) end

    it "should generate a certificate if requested" do
      subject.list(:all => true).should == []

      subject.generate('random-host')

      list = subject.list(:signed => true)
      list.length.should == 1
      list.first.name.should == 'random-host'
    end

    it "should not explode if a CSR with that name already exists" do
      make_certs('random-host', [])
      expect {
        subject.generate('random-host').should =~ /already has a certificate request/
      }.should_not raise_error
    end

    it "should not explode if the certificate with that name already exists" do
      make_certs([], 'random-host')
      expect {
        subject.generate('random-host').should =~ /already has a certificate/
      }.should_not raise_error
    end

    it "should include the specified DNS alt names" do
      subject.generate('some-host', :dns_alt_names => 'some,alt,names')

      host = subject.list(:signed => true).first

      host.name.should == 'some-host'
      host.certificate.subject_alt_names.should =~ %w[DNS:some DNS:alt DNS:names DNS:some-host]

      subject.list(:pending => true).should be_empty
    end
  end

  context "#revoke" do
    let :action do Puppet::Face[:ca, '0.1.0'].get_action(:revoke) end

    it "should not explode when asked to revoke something that doesn't exist" do
      expect { subject.revoke('nonesuch') }.should_not raise_error
    end

    it "should let the user know what went wrong" do
      subject.revoke('nonesuch').should == 'Nothing was revoked'
    end

    it "should revoke a certificate" do
      make_certs([], 'random-host')
      found = subject.list(:all => true, :subject => 'random-host')
      subject.get_action(:list).when_rendering(:console).call(found).
        should =~ /^\+ random-host/

      subject.revoke('random-host')

      found = subject.list(:all => true, :subject => 'random-host')
      subject.get_action(:list).when_rendering(:console).call(found).
        should =~ /^- random-host  \([:0-9A-F]+\) \(certificate revoked\)/
    end
  end

  context "#destroy" do
    let :action do Puppet::Face[:ca, '0.1.0'].get_action(:destroy) end

    it "should not explode when asked to delete something that doesn't exist" do
      expect { subject.destroy('nonesuch') }.should_not raise_error
    end

    it "should let the user know if nothing was deleted" do
      subject.destroy('nonesuch').should == "Nothing was deleted"
    end

    it "should destroy a CSR, if we have one" do
      make_certs('random-host', [])
      subject.list(:pending => true, :subject => 'random-host').should_not == []

      subject.destroy('random-host')

      subject.list(:pending => true, :subject => 'random-host').should == []
    end

    it "should destroy a certificate, if we have one" do
      make_certs([], 'random-host')
      subject.list(:signed => true, :subject => 'random-host').should_not == []

      subject.destroy('random-host')

      subject.list(:signed => true, :subject => 'random-host').should == []
    end

    it "should tell the user something was deleted" do
      make_certs([], 'random-host')
      subject.list(:signed => true, :subject => 'random-host').should_not == []
      subject.destroy('random-host').
        should == "Deleted for random-host: Puppet::SSL::Certificate, Puppet::SSL::Key"
    end
  end

  context "#list" do
    let :action do Puppet::Face[:ca, '0.1.0'].get_action(:list) end

    context "options" do
      subject { Puppet::Face[:ca, '0.1.0'].get_action(:list) }
      it { should be_option :pending }
      it { should be_option :signed  }
      it { should be_option :all     }
      it { should be_option :subject }
    end

    context "with no hosts in CA" do
      [:pending, :signed, :all].each do |type|
        it "should return nothing for #{type}" do
          subject.list(type => true).should == []
        end

        it "should not fail when a matcher is passed" do
          expect {
            subject.list(type => true, :subject => '.').should == []
          }.should_not raise_error
        end
      end
    end

    context "with some hosts" do
      csr_names = (1..3).map {|n| "csr-#{n}" }
      crt_names = (1..3).map {|n| "crt-#{n}" }
      all_names = csr_names + crt_names

      {
        {}                                    => csr_names,
        { :pending => true                  } => csr_names,

        { :signed  => true                  } => crt_names,

        { :all     => true                  } => all_names,
        { :pending => true, :signed => true } => all_names,
      }.each do |input, expect|
        it "should map #{input.inspect} to #{expect.inspect}" do
          make_certs(csr_names, crt_names)
          subject.list(input).map(&:name).should =~ expect
        end

        ['', '.', '2', 'none'].each do |pattern|
          filtered = expect.select {|x| Regexp.new(pattern).match(x) }

          it "should filter all hosts matching #{pattern.inspect} to #{filtered.inspect}" do
            make_certs(csr_names, crt_names)
            subject.list(input.merge :subject => pattern).map(&:name).should =~ filtered
          end
        end
      end

      context "when_rendering :console" do
        { [["csr1.local"], []] => '^  csr1.local ',
          [[], ["crt1.local"]] => '^\+ crt1.local ',
          [["csr2"], ["crt2"]] => ['^  csr2 ', '^\+ crt2 ']
        }.each do |input, pattern|
          it "should render #{input.inspect} to match #{pattern.inspect}" do
            make_certs(*input)
            text = action.when_rendering(:console).call(subject.list(:all => true))
            Array(pattern).each do |item|
              text.should =~ Regexp.new(item)
            end
          end
        end
      end
    end
  end

  actions = %w{destroy list revoke generate sign print verify fingerprint}
  actions.each do |action|
    it { should be_action action }
    it "should fail #{action} when not a CA" do
      Puppet[:ca] = false
      expect {
        case subject.method(action).arity
        when -1 then subject.send(action)
        when -2 then subject.send(action, 'dummy')
        else
          raise "#{action} has arity #{subject.method(action).arity}"
        end
      }.should raise_error(/Not a CA/)
    end
  end
end
