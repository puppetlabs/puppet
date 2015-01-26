#! /usr/bin/env ruby
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

  def given_certificate_requests_for(*names)
    names.each do |name|
      Puppet::SSL::Host.new(name).generate_certificate_request
    end
  end

  def given_certificates_for(*names)
    names.each do |name|
      Puppet::SSL::Host.new(name).generate
    end
  end

  context "#verify" do
    it "should report if there is no certificate" do
      expect(subject.verify('random-host')).to eq({
        :host => 'random-host', :valid => false,
        :error => 'Could not find a certificate for random-host'
      })
    end

    it "should report that it cannot find a certificate when there is only a request" do
      given_certificate_requests_for('random-host')

      expect(subject.verify('random-host')).to eq({
        :host => 'random-host', :valid => false,
        :error => 'Could not find a certificate for random-host'
      })
    end

    it "should verify a signed certificate" do
      given_certificates_for('random-host')

      expect(subject.verify('random-host')).to eq({
        :host => 'random-host', :valid => true
      })
    end

    it "should not verify a revoked certificate" do
      given_certificates_for('random-host')

      subject.revoke('random-host')

      expect(subject.verify('random-host')).to eq({
        :host => 'random-host', :valid => false,
        :error => 'certificate revoked'
      })
    end

    it "should verify a revoked certificate if CRL use was turned off" do
      given_certificates_for('random-host')
      subject.revoke('random-host')

      Puppet[:certificate_revocation] = false

      expect(subject.verify('random-host')).to eq({
        :host => 'random-host', :valid => true
      })
    end
  end

  context "#fingerprint" do
    let(:fingerprint_re) { /^\([0-9A-Z]+\) [0-9A-F:]+$/ }

    it "should be nil if there is no certificate" do
      expect(subject.fingerprint('random-host')).to be_nil
    end

    it "should fingerprint a CSR" do
      given_certificate_requests_for('random-host')

      expect(subject.fingerprint('random-host')).to match(fingerprint_re)
    end

    it "should fingerprint a certificate" do
      given_certificates_for('random-host')

      expect(subject.fingerprint('random-host')).to match(fingerprint_re)
    end

    %w{md5 MD5 sha1 SHA1 RIPEMD160 sha256 sha512}.each do |digest|
      it "should fingerprint with #{digest.inspect}" do
        given_certificates_for('random-host')

        expect(subject.fingerprint('random-host', :digest => digest)).to match(fingerprint_re)
      end
    end
  end

  context "#print" do
    it "should be nil if there is no certificate" do
      expect(subject.print('random-host')).to be_nil
    end

    it "should return nothing if there is only a CSR" do
      given_certificate_requests_for('random-host')

      expect(subject.print('random-host')).to be_nil
    end

    it "should return the certificate content if there is a cert" do
      given_certificates_for('random-host')

      text = subject.print('random-host')

      expect(text).to be_an_instance_of String
      expect(text).to match(/^Certificate:/)
      expect(text).to match(/Issuer: CN=Puppet CA: /)
      expect(text).to match(/Subject: CN=random-host$/)
    end
  end

  context "#sign" do
    it "should report that there is no CSR" do
      expect(subject.sign('random-host')).to eq('Could not find certificate request for random-host')
    end

    it "should report that there is no CSR when even when there is a certificate" do
      given_certificates_for('random-host')

      expect(subject.sign('random-host')).to eq('Could not find certificate request for random-host')
    end

    it "should sign a CSR if one exists" do
      given_certificate_requests_for('random-host')

      expect(subject.sign('random-host')).to be_an_instance_of Puppet::SSL::Certificate

      list = subject.list(:signed => true)
      expect(list.length).to eq(1)
      expect(list.first.name).to eq('random-host')
    end

    describe "when the CSR specifies DNS alt names" do
      let(:host) { Puppet::SSL::Host.new('someone') }

      before :each do
        host.generate_certificate_request(:dns_alt_names => 'some,alt,names')
      end

      it "should sign the CSR if DNS alt names are allowed" do
        subject.sign('someone', :allow_dns_alt_names => true)

        expect(host.certificate).to be_a(Puppet::SSL::Certificate)
      end

      it "should refuse to sign the CSR if DNS alt names are not allowed" do
        certname = 'someone'
        expect do
          subject.sign(certname)
        end.to raise_error(Puppet::SSL::CertificateAuthority::CertificateSigningError, /CSR '#{certname}' contains subject alternative names \(.*\), which are disallowed. Use `puppet cert --allow-dns-alt-names sign #{certname}` to sign this request./i)

        expect(host.certificate).to be_nil
      end
    end
  end

  context "#generate" do
    it "should generate a certificate if requested" do
      expect(subject.list(:all => true)).to eq([])

      subject.generate('random-host')

      list = subject.list(:signed => true)
      expect(list.length).to eq(1)
      expect(list.first.name).to eq('random-host')
    end

    it "should report if a CSR with that name already exists" do
      given_certificate_requests_for('random-host')

      expect(subject.generate('random-host')).to match(/already has a certificate request/)
    end

    it "should report if the certificate with that name already exists" do
      given_certificates_for('random-host')

      expect(subject.generate('random-host')).to match(/already has a certificate/)
    end

    it "should include the specified DNS alt names" do
      subject.generate('some-host', :dns_alt_names => 'some,alt,names')

      host = subject.list(:signed => true).first

      expect(host.name).to eq('some-host')
      expect(host.certificate.subject_alt_names).to match_array(%w[DNS:some DNS:alt DNS:names DNS:some-host])

      expect(subject.list(:pending => true)).to be_empty
    end
  end

  context "#revoke" do
    it "should let the user know what went wrong when there is nothing to revoke" do
      expect(subject.revoke('nonesuch')).to eq('Nothing was revoked')
    end

    it "should revoke a certificate" do
      given_certificates_for('random-host')

      subject.revoke('random-host')

      found = subject.list(:all => true, :subject => 'random-host')
      expect(subject.get_action(:list).when_rendering(:console).call(found, {})).
        to match(/^- random-host  \(\w+\) [:0-9A-F]+ \(certificate revoked\)/)
    end
  end

  context "#destroy" do
    it "should let the user know if nothing was deleted" do
      expect(subject.destroy('nonesuch')).to eq("Nothing was deleted")
    end

    it "should destroy a CSR, if we have one" do
      given_certificate_requests_for('random-host')

      subject.destroy('random-host')

      expect(subject.list(:pending => true, :subject => 'random-host')).to eq([])
    end

    it "should destroy a certificate, if we have one" do
      given_certificates_for('random-host')

      subject.destroy('random-host')

      expect(subject.list(:signed => true, :subject => 'random-host')).to eq([])
    end

    it "should tell the user something was deleted" do
      given_certificates_for('random-host')

      expect(subject.list(:signed => true, :subject => 'random-host')).not_to eq([])

      expect(subject.destroy('random-host')).
        to eq("Deleted for random-host: Puppet::SSL::Certificate")
    end
  end

  context "#list" do
    context "with no hosts in CA" do
      [
        {},
        { :pending => true },
        { :signed => true },
        { :all => true },
      ].each do |type|
        it "should return nothing for #{type.inspect}" do
          expect(subject.list(type)).to eq([])
        end

        it "should return nothing when a matcher is passed" do
          expect(subject.list(type.merge :subject => '.')).to eq([])
        end

        context "when_rendering :console" do
          it "should return nothing for #{type.inspect}" do
            expect(subject.get_action(:list).when_rendering(:console).call(subject.list(type), {})).to eq("")
          end
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
          given_certificate_requests_for(*csr_names)
          given_certificates_for(*crt_names)

          expect(subject.list(input).map(&:name)).to match_array(expect)
        end

        ['', '.', '2', 'none'].each do |pattern|
          filtered = expect.select {|x| Regexp.new(pattern).match(x) }

          it "should filter all hosts matching #{pattern.inspect} to #{filtered.inspect}" do
            given_certificate_requests_for(*csr_names)
            given_certificates_for(*crt_names)

            expect(subject.list(input.merge :subject => pattern).map(&:name)).to match_array(filtered)
          end
        end
      end

      context "when_rendering :console" do
        { [["csr1.local"], []] => [/^  csr1.local /],
          [[], ["crt1.local"]] => [/^\+ crt1.local /],
          [["csr2"], ["crt2"]] => [/^  csr2 /, /^\+ crt2 /]
        }.each do |input, pattern|
          it "should render #{input.inspect} to match #{pattern.inspect}" do
            given_certificate_requests_for(*input[0])
            given_certificates_for(*input[1])

            text = subject.get_action(:list).when_rendering(:console).call(subject.list(:all => true), {})

            pattern.each do |item|
              expect(text).to match(item)
            end
          end
        end
      end
    end
  end

  actions = %w{destroy list revoke generate sign print verify fingerprint}
  actions.each do |action|
    it { is_expected.to be_action action }
    it "should fail #{action} when not a CA" do
      Puppet[:ca] = false
      expect {
        case subject.method(action).arity
        when -1 then subject.send(action)
        when -2 then subject.send(action, 'dummy')
        else
          raise "#{action} has arity #{subject.method(action).arity}"
        end
      }.to raise_error(/Not a CA/)
    end
  end
end
