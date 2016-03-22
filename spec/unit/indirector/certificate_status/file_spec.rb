#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/ssl/host'
require 'puppet/indirector/certificate_status'
require 'tempfile'

describe "Puppet::Indirector::CertificateStatus::File" do
  include PuppetSpec::Files

  before :all do
    Puppet::SSL::Host.configure_indirection(:file)
  end

  before do
    Puppet::SSL::CertificateAuthority.stubs(:ca?).returns true
    @terminus = Puppet::SSL::Host.indirection.terminus(:file)

    @tmpdir = tmpdir("certificate_status_ca_testing")
    Puppet[:confdir] = @tmpdir
    Puppet[:vardir] = @tmpdir

    # localcacert is where each client stores the CA certificate
    # cacert is where the master stores the CA certificate
    # Since we need to play the role of both for testing we need them to be the same and exist
    Puppet[:cacert] = Puppet[:localcacert]
  end

  def generate_csr(host)
    host.generate_key
    csr = Puppet::SSL::CertificateRequest.new(host.name)
    csr.generate(host.key.content)
    Puppet::SSL::CertificateRequest.indirection.save(csr)
  end

  def sign_csr(host)
    host.desired_state = "signed"
    @terminus.save(Puppet::Indirector::Request.new(:certificate_status, :save, host.name, host))
  end

  def generate_signed_cert(host)
    generate_csr(host)
    sign_csr(host)

    @terminus.find(Puppet::Indirector::Request.new(:certificate_status, :find, host.name, host))
  end

  def generate_revoked_cert(host)
    generate_signed_cert(host)

    host.desired_state = "revoked"

    @terminus.save(Puppet::Indirector::Request.new(:certificate_status, :save, host.name, host))
  end

  it "should be a terminus on SSL::Host" do
    expect(@terminus).to be_instance_of(Puppet::Indirector::CertificateStatus::File)
  end

  it "should create a CA instance if none is present" do
    expect(@terminus.ca).to be_instance_of(Puppet::SSL::CertificateAuthority)
  end

  describe "when creating the CA" do
    it "should fail if it is not a valid CA" do
      Puppet::SSL::CertificateAuthority.expects(:ca?).returns false
      expect { @terminus.ca }.to raise_error(ArgumentError, "This process is not configured as a certificate authority")
    end
  end

  it "should be indirected with the name 'certificate_status'" do
    expect(Puppet::SSL::Host.indirection.name).to eq(:certificate_status)
  end

  describe "when finding" do
    before do
      @host = Puppet::SSL::Host.new("foo")
      Puppet.settings.use(:main)
    end

    it "should return the Puppet::SSL::Host when a CSR exists for the host" do
      generate_csr(@host)
      request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)

      retrieved_host = @terminus.find(request)

      expect(retrieved_host.name).to eq(@host.name)
      expect(retrieved_host.certificate_request.content.to_s.chomp).to eq(@host.certificate_request.content.to_s.chomp)
    end

    it "should return the Puppet::SSL::Host when a public key exists for the host" do
      generate_signed_cert(@host)
      request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)

      retrieved_host = @terminus.find(request)

      expect(retrieved_host.name).to eq(@host.name)
      expect(retrieved_host.certificate.content.to_s.chomp).to eq(@host.certificate.content.to_s.chomp)
    end

    it "should return nil when neither a CSR nor public key exist for the host" do
      request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)
      expect(@terminus.find(request)).to eq(nil)
    end
  end

  describe "when saving" do
    before do
      @host = Puppet::SSL::Host.new("foobar")
      Puppet.settings.use(:main)
    end

    describe "when signing a cert" do
      before do
        @host.desired_state = "signed"
        @request = Puppet::Indirector::Request.new(:certificate_status, :save, "foobar", @host)
      end

      it "should fail if no CSR is on disk" do
        expect { @terminus.save(@request) }.to raise_error(Puppet::Error, /certificate request/)
      end

      it "should sign the on-disk CSR when it is present" do
        signed_host = generate_signed_cert(@host)

        expect(signed_host.state).to eq("signed")
        expect(Puppet::SSL::Certificate.indirection.find("foobar")).to be_instance_of(Puppet::SSL::Certificate)
      end
    end

    describe "when revoking a cert" do
      before do
        @request = Puppet::Indirector::Request.new(:certificate_status, :save, "foobar", @host)
      end

      it "should fail if no certificate is on disk" do
        @host.desired_state = "revoked"
        expect { @terminus.save(@request) }.to raise_error(Puppet::Error, /Cannot revoke/)
      end

      it "should revoke the certificate when it is present" do
        generate_revoked_cert(@host)

        expect(@host.state).to eq('revoked')
      end
    end
  end

  describe "when deleting" do
    before do
      Puppet.settings.use(:main)
    end

    it "should not delete anything if no certificate, request, or key is on disk" do
      host = Puppet::SSL::Host.new("clean_me")
      request = Puppet::Indirector::Request.new(:certificate_status, :delete, "clean_me", host)
      expect(@terminus.destroy(request)).to eq("Nothing was deleted")
    end

    it "should clean certs, cert requests, keys" do
      signed_host = Puppet::SSL::Host.new("clean_signed_cert")
      generate_signed_cert(signed_host)
      signed_request = Puppet::Indirector::Request.new(:certificate_status, :delete, "clean_signed_cert", signed_host)
      expect(@terminus.destroy(signed_request)).to eq("Deleted for clean_signed_cert: Puppet::SSL::Certificate, Puppet::SSL::Key")

      requested_host = Puppet::SSL::Host.new("clean_csr")
      generate_csr(requested_host)
      csr_request = Puppet::Indirector::Request.new(:certificate_status, :delete, "clean_csr", requested_host)
      expect(@terminus.destroy(csr_request)).to eq("Deleted for clean_csr: Puppet::SSL::CertificateRequest, Puppet::SSL::Key")
    end
  end

  describe "when searching" do
    it "should return a list of all hosts with certificate requests, signed certs, or revoked certs" do
      Puppet.settings.use(:main)

      signed_host = Puppet::SSL::Host.new("signed_host")
      generate_signed_cert(signed_host)

      requested_host = Puppet::SSL::Host.new("requested_host")
      generate_csr(requested_host)

      revoked_host = Puppet::SSL::Host.new("revoked_host")
      generate_revoked_cert(revoked_host)

      retrieved_hosts = @terminus.search(Puppet::Indirector::Request.new(:certificate_status, :search, "all", signed_host))

      results = retrieved_hosts.map {|h| [h.name, h.state]}.sort{ |h,i| h[0] <=> i[0] }
      expect(results).to eq([["ca","signed"],["requested_host","requested"],["revoked_host","revoked"],["signed_host","signed"]])
    end
  end
end
