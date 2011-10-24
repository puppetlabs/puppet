require 'spec_helper'

require 'puppet/network/handler/ca'

describe Puppet::Network::Handler::CA do
  include PuppetSpec::Files

  describe "#getcert" do
    let(:host)      { "testhost" }
    let(:x509_name) { OpenSSL::X509::Name.new [['CN', host]] }
    let(:key)       { Puppet::SSL::Key.new(host).generate }

    let(:csr) do
      csr = OpenSSL::X509::Request.new
      csr.subject = x509_name
      csr.public_key = key.public_key
      csr
    end

    let(:ca)     { Puppet::SSL::CertificateAuthority.new }
    let(:cacert) { ca.instance_variable_get(:@certificate) }

    before :each do
      Puppet[:confdir] = tmpdir('conf')

      Puppet::SSL::CertificateAuthority.stubs(:ca?).returns true
      Puppet::SSL::CertificateAuthority.stubs(:singleton_instance).returns ca
    end

    it "should do nothing if the master is not a CA" do
      Puppet::SSL::CertificateAuthority.stubs(:ca?).returns false

      csr = OpenSSL::X509::Request.new
      subject.getcert(csr.to_pem).should == ''
    end

    describe "when a certificate already exists for the host" do
      let!(:cert)    { ca.generate(host) }

      it "should return the existing cert if it matches the public key of the CSR" do
        csr.public_key = cert.content.public_key

        subject.getcert(csr.to_pem).should == [cert.to_s, cacert.to_s]
      end

      it "should fail if the public key of the CSR does not match the existing cert" do
        expect do
          subject.getcert(csr.to_pem)
        end.to raise_error(Puppet::Error, /Certificate request does not match existing certificate/)
      end
    end

    describe "when autosign is enabled" do
      before :each do
        Puppet[:autosign] = true
      end

      it "should return the new cert and the CA cert" do
        cert_str, cacert_str = subject.getcert(csr.to_pem)

        returned_cert = Puppet::SSL::Certificate.from_s(cert_str)
        returned_cacert = Puppet::SSL::Certificate.from_s(cacert_str)

        returned_cert.name.should == host
        returned_cacert.content.subject.cmp(cacert.content.subject).should == 0
      end
    end

    describe "when autosign is disabled" do
      before :each do
        Puppet[:autosign] = false
      end

      it "should save the CSR without signing it" do
        subject.getcert(csr.to_pem)

        Puppet::SSL::Certificate.indirection.find(host).should be_nil
        Puppet::SSL::CertificateRequest.indirection.find(host).should be_a(Puppet::SSL::CertificateRequest)
      end

      it "should not return a cert" do
        subject.getcert(csr.to_pem).should be_nil
      end
    end
  end
end
