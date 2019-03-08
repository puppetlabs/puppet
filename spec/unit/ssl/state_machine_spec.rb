require 'spec_helper'
require 'webmock/rspec'
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

  let(:private_key) { key_fixture('signed-key.pem') }
  let(:client_cert) { cert_fixture('signed.pem') }

  before(:each) do
    WebMock.disable_net_connect!

    Net::HTTP.any_instance.stubs(:start)
    Net::HTTP.any_instance.stubs(:finish)
  end

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

    it "does not verify the server's cert if there are no local CA certs" do
      Puppet::X509::CertProvider.any_instance.stubs(:load_cacerts).returns(nil)
      stub_request(:get, %r{puppet-ca/v1/certificate/ca}).to_return(status: 200, body: cacert_pem)
      Puppet::X509::CertProvider.any_instance.stubs(:save_cacerts)

      Net::HTTP.any_instance.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

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

      state.next_state rescue OpenSSL::X509::CertificateError

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

    it "verifies the server's certificate when fetching the CRL" do
      pending("CRL download")
      Puppet::X509::CertProvider.any_instance.stubs(:load_crls).returns(nil)
      stub_request(:get, %r{puppet-ca/v1/certificate_revocation_list/ca}).to_return(status: 200, body: crl_pem)
      Puppet::X509::CertProvider.any_instance.stubs(:save_crls)

      Net::HTTP.any_instance.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

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

      state.next_state rescue OpenSSL::X509::CRLError

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

  context 'when ensuring a client cert' do
    context 'in state NeedKey' do
      let(:ssl_context) { Puppet::SSL::SSLContext.new(cacerts: cacerts, crls: crls)}
      let(:state) { Puppet::SSL::StateMachine::NeedKey.new(ssl_context) }

      it 'loads an existing private key and passes it to the next state' do
        Puppet::X509::CertProvider.any_instance.stubs(:load_private_key).returns(private_key)

        st = state.next_state
        expect(st).to be_instance_of(Puppet::SSL::StateMachine::NeedSubmitCSR)
        expect(st.private_key).to eq(private_key)
      end

      it 'loads a matching private key and cert' do
        Puppet::X509::CertProvider.any_instance.stubs(:load_private_key).returns(private_key)
        Puppet::X509::CertProvider.any_instance.stubs(:load_client_cert).returns(client_cert)

        st = state.next_state
        expect(st).to be_instance_of(Puppet::SSL::StateMachine::Done)
      end

      it 'raises if the client cert is mismatched' do
        Puppet::X509::CertProvider.any_instance.stubs(:load_private_key).returns(private_key)
        Puppet::X509::CertProvider.any_instance.stubs(:load_client_cert).returns(cert_fixture('tampered-cert.pem'))

        expect {
          state.next_state
        }.to raise_error(Puppet::SSL::SSLError, %r{The certificate for '/CN=signed' does not match its private key})
      end

      it 'generates a new private key, saves it and passes it to the next state' do
        Puppet::X509::CertProvider.any_instance.stubs(:load_private_key).returns(nil)
        Puppet::X509::CertProvider.any_instance.expects(:save_private_key)

        st = state.next_state
        expect(st).to be_instance_of(Puppet::SSL::StateMachine::NeedSubmitCSR)
        expect(st.private_key).to be_instance_of(OpenSSL::PKey::RSA)
      end

      it 'raises an error if it fails to load the key' do
        Puppet::X509::CertProvider.any_instance.stubs(:load_private_key).raises(OpenSSL::PKey::RSAError)

        expect {
          state.next_state
        }.to raise_error(OpenSSL::PKey::RSAError)
      end
    end
  end
end
