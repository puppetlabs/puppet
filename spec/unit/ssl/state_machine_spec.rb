require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/ssl'

describe Puppet::SSL::StateMachine do
  include PuppetSpec::Files

  let(:machine) { described_class.new }
  let(:cacert_pem) { cacert.to_pem }
  let(:cacert) { cert_fixture('ca.pem') }
  let(:cacerts) { [cacert] }

  let(:crl_pem) { crl.to_pem }
  let(:crl) { crl_fixture('crl.pem') }
  let(:crls) { [crl] }

  context 'when ensuring CA certs and CRLs' do
    it 'returns an SSLContext with the loaded CA certs and CRLs' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_cacerts).returns(cacerts)
      Puppet::X509::CertProvider.any_instance.stubs(:load_crls).returns(crls)

      ssl_context = machine.ensure_ca_certificates

      expect(ssl_context[:cacerts]).to eq(cacerts)
      expect(ssl_context[:crls]).to eq(crls)
      expect(ssl_context[:verify_peer]).to eq(true)
    end
  end

  context 'NeedCACerts' do
    let(:state) { Puppet::SSL::StateMachine::NeedCACerts.new }

    before :each do
      Puppet[:localcacert] = tmpfile('needcacerts')
    end

    it 'transitions to NeedCRLs state' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_cacerts).returns(cacerts)

      expect(state.next_state).to be_an_instance_of(Puppet::SSL::StateMachine::NeedCRLs)
    end

    it 'loads existing CA certs' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_cacerts).returns(cacerts)

      st = state.next_state
      expect(st.ssl_context[:cacerts]).to eq(cacerts)
    end

    it 'fetches and saves CA certs' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_cacerts).returns(nil)
      Puppet::SSL::Fetcher.any_instance.stubs(:fetch_cacerts).returns(cacert_pem)

      st = state.next_state
      expect(st.ssl_context[:cacerts].map(&:to_pem)).to eq(cacerts.map(&:to_pem))
      expect(File).to be_exist(Puppet[:localcacert])
    end

    it 'does not verify the peer cert if there are no local CA certs' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_cacerts).returns(nil)

      Puppet::Rest::Routes.expects(:get_certificate).with do |_, ssl_context|
        expect(ssl_context[:verify_peer]).to eq(false)
      end.returns(cacert_pem)

      state.next_state
    end

    it 'raises if CA certs are invalid' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_cacerts).returns(nil)
      Puppet::SSL::Fetcher.any_instance.stubs(:fetch_cacerts).returns('')

      expect {
        state.next_state
      }.to raise_error(OpenSSL::X509::CertificateError)
    end

    it 'does not save invalid CA certs' do
      Puppet::SSL::Fetcher.any_instance.stubs(:fetch_cacerts).returns(<<~END)
        -----BEGIN CERTIFICATE-----
        MIIBpDCCAQ2gAwIBAgIBAjANBgkqhkiG9w0BAQsFADAfMR0wGwYDVQQDDBRUZXN0
      END

      state.next_state rescue nil

      expect(File).to_not exist(Puppet[:localcacert])
    end
  end

  context 'NeedCRLs' do
    let(:ssl_context) { Puppet::SSL::SSLContext.new(cacerts: cacerts)}
    let(:state) { Puppet::SSL::StateMachine::NeedCRLs.new(ssl_context) }

    before :each do
      Puppet[:hostcrl] = tmpfile('needcrls')
    end

    it 'transitions to NeedKey state' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_crls).returns(crls)

      expect(state.next_state).to be_an_instance_of(Puppet::SSL::StateMachine::NeedKey)
    end

    it 'loads existing CRLs' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_crls).returns(crls)

      st = state.next_state
      expect(st.ssl_context[:crls]).to eq(crls)
    end

    it 'fetches and saves CRLs' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_crls).returns(nil)
      Puppet::SSL::Fetcher.any_instance.stubs(:fetch_crls).returns(crl_pem)

      st = state.next_state
      expect(st.ssl_context[:crls].map(&:to_pem)).to eq(crls.map(&:to_pem))
      expect(File).to be_exist(Puppet[:hostcrl])
    end

    it 'verifies the peer certificate when fetching the CRL' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_crls).returns(nil)

      Puppet::Rest::Routes.expects(:get_crls).with do |_, ssl_context|
        expect(ssl_context[:verify_peer]).to eq(true)
      end.returns(crl_pem)

      state.next_state
    end

    it 'raises if CRLs are invalid' do
      Puppet::X509::CertProvider.any_instance.stubs(:load_crls).returns(nil)
      Puppet::SSL::Fetcher.any_instance.stubs(:fetch_crls).returns('')

      expect {
        state.next_state
      }.to raise_error(OpenSSL::X509::CRLError)
    end

    it 'does not save invalid CRLs' do
      Puppet::SSL::Fetcher.any_instance.stubs(:fetch_crls).returns(<<~END)
        -----BEGIN X509 CRL-----
        MIIBCjB1AgEBMA0GCSqGSIb3DQEBCwUAMBIxEDAOBgNVBAMMB1Rlc3QgQ0EXDTcw
      END

      state.next_state rescue nil

      expect(File).to_not exist(Puppet[:hostcrl])
    end

    it 'skips CRL download when revocation is disabled' do
      Puppet[:certificate_revocation] = false

      Puppet::X509::CertProvider.any_instance.expects(:load_crls).never
      Puppet::Rest::Routes.expects(:get_crls).never

      state.next_state

      expect(File).to_not exist(Puppet[:hostcrl])
    end
  end
end
