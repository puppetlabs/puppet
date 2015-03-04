require 'spec_helper'
require 'puppet/ssl'

describe Puppet::SSL::Validator::DefaultValidator do
  let(:ssl_context) do
    mock('OpenSSL::X509::StoreContext')
  end

  let(:ssl_configuration) do
    Puppet::SSL::Configuration.new(
      Puppet[:localcacert],
      :ca_auth_file  => Puppet[:ssl_client_ca_auth])
  end

  let(:ssl_host) do
    stub('ssl_host',
         :ssl_store => nil,
         :certificate => stub('cert', :content => nil),
         :key => stub('key', :content => nil))
  end

  subject do
    described_class.new(ssl_configuration,
                        ssl_host)
  end

  before :each do
    ssl_configuration.stubs(:read_file).
      with(Puppet[:localcacert]).
      returns(root_ca)
  end

  describe '#call' do
    before :each do
      ssl_context.stubs(:current_cert).returns(*cert_chain_in_callback_order)
      ssl_context.stubs(:chain).returns(cert_chain)
    end

    context 'When pre-verification is not OK' do
      context 'and the ssl_context is in an error state' do
        let(:root_subject) { OpenSSL::X509::Certificate.new(root_ca).subject.to_s }
        let(:code) { OpenSSL::X509::V_ERR_INVALID_CA }

        it 'rejects the connection' do
          ssl_context.stubs(:error_string).returns("Something went wrong")
          ssl_context.stubs(:error).returns(code)

          expect(subject.call(false, ssl_context)).to eq(false)
        end

        it 'makes the error available via #verify_errors' do
          ssl_context.stubs(:error_string).returns("Something went wrong")
          ssl_context.stubs(:error).returns(code)

          subject.call(false, ssl_context)
          expect(subject.verify_errors).to eq(["Something went wrong for #{root_subject}"])
        end

        it 'uses a generic message if error_string is nil' do
          ssl_context.stubs(:error_string).returns(nil)
          ssl_context.stubs(:error).returns(code)

          subject.call(false, ssl_context)
          expect(subject.verify_errors).to eq(["OpenSSL error #{code} for #{root_subject}"])
        end

        it 'uses 0 for nil error codes' do
          ssl_context.stubs(:error_string).returns("Something went wrong")
          ssl_context.stubs(:error).returns(nil)

          subject.call(false, ssl_context)
          expect(subject.verify_errors).to eq(["Something went wrong for #{root_subject}"])
        end

        context "when CRL is not yet valid" do
          before :each do
            ssl_context.stubs(:error_string).returns("CRL is not yet valid")
            ssl_context.stubs(:error).returns(OpenSSL::X509::V_ERR_CRL_NOT_YET_VALID)
          end

          it 'rejects nil CRL' do
            ssl_context.stubs(:current_crl).returns(nil)

            expect(subject.call(false, ssl_context)).to eq(false)
            expect(subject.verify_errors).to eq(["CRL is not yet valid"])
          end

          it 'includes the CRL issuer in the verify error message' do
            crl = OpenSSL::X509::CRL.new
            crl.issuer = OpenSSL::X509::Name.new([['CN','Puppet CA: puppetmaster.example.com']])
            crl.last_update = Time.now + 24 * 60 * 60
            ssl_context.stubs(:current_crl).returns(crl)

            subject.call(false, ssl_context)
            expect(subject.verify_errors).to eq(["CRL is not yet valid for /CN=Puppet CA: puppetmaster.example.com"])
          end

          it 'rejects CRLs whose last_update time is more than 5 minutes in the future' do
            crl = OpenSSL::X509::CRL.new
            crl.issuer = OpenSSL::X509::Name.new([['CN','Puppet CA: puppetmaster.example.com']])
            crl.last_update = Time.now + 24 * 60 * 60
            ssl_context.stubs(:current_crl).returns(crl)

            expect(subject.call(false, ssl_context)).to eq(false)
          end

          it 'accepts CRLs whose last_update time is 10 seconds in the future' do
            crl = OpenSSL::X509::CRL.new
            crl.issuer = OpenSSL::X509::Name.new([['CN','Puppet CA: puppetmaster.example.com']])
            crl.last_update = Time.now + 10
            ssl_context.stubs(:current_crl).returns(crl)

            expect(subject.call(false, ssl_context)).to eq(true)
          end
        end
      end
    end

    context 'When pre-verification is OK' do
      context 'and the ssl_context is in an error state' do
        before :each do
          ssl_context.stubs(:error_string).returns("Something went wrong")
        end

        it 'does not make the error available via #verify_errors' do
          subject.call(true, ssl_context)
          expect(subject.verify_errors).to eq([])
        end
      end

      context 'and the chain is valid' do
        it 'is true for each CA certificate in the chain' do
          (cert_chain.length - 1).times do
            expect(subject.call(true, ssl_context)).to be_truthy
          end
        end

        it 'is true for the SSL certificate ending the chain' do
          (cert_chain.length - 1).times do
            subject.call(true, ssl_context)
          end
          expect(subject.call(true, ssl_context)).to be_truthy
        end
      end

      context 'and the chain is invalid' do
        before :each do
          ssl_configuration.stubs(:read_file).
            with(Puppet[:localcacert]).
            returns(agent_ca)
        end

        it 'is true for each CA certificate in the chain' do
          (cert_chain.length - 1).times do
            expect(subject.call(true, ssl_context)).to be_truthy
          end
        end

        it 'is false for the SSL certificate ending the chain' do
          (cert_chain.length - 1).times do
            subject.call(true, ssl_context)
          end
          expect(subject.call(true, ssl_context)).to be_falsey
        end
      end

      context 'an error is raised inside of #call' do
        before :each do
          ssl_context.expects(:current_cert).raises(StandardError, "BOOM!")
        end

        it 'is false' do
          expect(subject.call(true, ssl_context)).to be_falsey
        end

        it 'makes the error available through #verify_errors' do
          subject.call(true, ssl_context)
          expect(subject.verify_errors).to eq(["BOOM!"])
        end
      end
    end
  end

  describe '#setup_connection' do
    it 'updates the connection for verification' do
      subject.stubs(:ssl_certificates_are_present?).returns(true)
      connection = mock('Net::HTTP')

      connection.expects(:cert_store=).with(ssl_host.ssl_store)
      connection.expects(:ca_file=).with(ssl_configuration.ca_auth_file)
      connection.expects(:cert=).with(ssl_host.certificate.content)
      connection.expects(:key=).with(ssl_host.key.content)
      connection.expects(:verify_callback=).with(subject)
      connection.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

      subject.setup_connection(connection)
    end

    it 'does not perform verification if certificate files are missing' do
      subject.stubs(:ssl_certificates_are_present?).returns(false)
      connection = mock('Net::HTTP')

      connection.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      subject.setup_connection(connection)
    end
  end

  describe '#valid_peer?' do
    before :each do
      peer_certs = cert_chain_in_callback_order.map do |c|
        Puppet::SSL::Certificate.from_instance(c)
      end
      subject.instance_variable_set(:@peer_certs, peer_certs)
    end

    context 'when the peer presents a valid chain' do
      before :each do
        subject.stubs(:has_authz_peer_cert).returns(true)
      end

      it 'is true' do
        expect(subject.valid_peer?).to be_truthy
      end
    end

    context 'when the peer presents an invalid chain' do
      before :each do
        subject.stubs(:has_authz_peer_cert).returns(false)
      end

      it 'is false' do
        expect(subject.valid_peer?).to be_falsey
      end

      it 'makes a helpful error message available via #verify_errors' do
        subject.valid_peer?
        expect(subject.verify_errors).to eq([expected_authz_error_msg])
      end
    end
  end

  describe '#has_authz_peer_cert' do
    context 'when the Root CA is listed as authorized' do
      it 'returns true when the SSL cert is issued by the Master CA' do
        expect(subject.has_authz_peer_cert(cert_chain, [root_ca_cert])).to be_truthy
      end

      it 'returns true when the SSL cert is issued by the Agent CA' do
        expect(subject.has_authz_peer_cert(cert_chain_agent_ca, [root_ca_cert])).to be_truthy
      end
    end

    context 'when the Master CA is listed as authorized' do
      it 'returns false when the SSL cert is issued by the Master CA' do
        expect(subject.has_authz_peer_cert(cert_chain, [master_ca_cert])).to be_truthy
      end

      it 'returns true when the SSL cert is issued by the Agent CA' do
        expect(subject.has_authz_peer_cert(cert_chain_agent_ca, [master_ca_cert])).to be_falsey
      end
    end

    context 'when the Agent CA is listed as authorized' do
      it 'returns true when the SSL cert is issued by the Master CA' do
        expect(subject.has_authz_peer_cert(cert_chain, [agent_ca_cert])).to be_falsey
      end

      it 'returns true when the SSL cert is issued by the Agent CA' do
        expect(subject.has_authz_peer_cert(cert_chain_agent_ca, [agent_ca_cert])).to be_truthy
      end
    end
  end

  def root_ca
    <<-ROOT_CA
-----BEGIN CERTIFICATE-----
MIICYDCCAcmgAwIBAgIJALf2Pk2HvtBzMA0GCSqGSIb3DQEBBQUAMEkxEDAOBgNV
BAMMB1Jvb3QgQ0ExGjAYBgNVBAsMEVNlcnZlciBPcGVyYXRpb25zMRkwFwYDVQQK
DBBFeGFtcGxlIE9yZywgTExDMB4XDTEzMDMzMDA1NTA0OFoXDTMzMDMyNTA1NTA0
OFowSTEQMA4GA1UEAwwHUm9vdCBDQTEaMBgGA1UECwwRU2VydmVyIE9wZXJhdGlv
bnMxGTAXBgNVBAoMEEV4YW1wbGUgT3JnLCBMTEMwgZ8wDQYJKoZIhvcNAQEBBQAD
gY0AMIGJAoGBAMGSpafR4lboYOPfPJC1wVHHl0gD49ZVRjOlJ9jidEUjBdFXK6SA
S1tecDv2G4tM1ANmfMKjZl0m+KaZ8O2oq0g6kxkq1Mg0eSNvlnEyehjmTLRzHC2i
a0biH2wMtCLzfAoXDKy4GPlciBPE9mup5I8Kien5s91t92tc7K8AJ8oBAgMBAAGj
UDBOMB0GA1UdDgQWBBQwTdZqjjXOIFK2hOM0bcOrnhQw2jAfBgNVHSMEGDAWgBQw
TdZqjjXOIFK2hOM0bcOrnhQw2jAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUA
A4GBACs8EZRrzgzAlcKC1Tz8GYlNHQg0XhpbEDm+p2mOV//PuDD190O+UBpWxo9Q
rrkkx8En0wXQZJf6iH3hwewwHLOq5yXZKbJN+SmvJvRNL95Yhyy08Y9N65tJveE7
rPsNU/Tx19jHC87oXlmAePLI4IaUHXrWb7CRbY9TEcPdmj1R
-----END CERTIFICATE-----
    ROOT_CA
  end

  def master_ca
    <<-MASTER_CA
-----BEGIN CERTIFICATE-----
MIICljCCAf+gAwIBAgIBAjANBgkqhkiG9w0BAQUFADBJMRAwDgYDVQQDDAdSb290
IENBMRowGAYDVQQLDBFTZXJ2ZXIgT3BlcmF0aW9uczEZMBcGA1UECgwQRXhhbXBs
ZSBPcmcsIExMQzAeFw0xMzAzMzAwNTUwNDhaFw0zMzAzMjUwNTUwNDhaMH4xJDAi
BgNVBAMTG0ludGVybWVkaWF0ZSBDQSAobWFzdGVyLWNhKTEfMB0GCSqGSIb3DQEJ
ARYQdGVzdEBleGFtcGxlLm9yZzEZMBcGA1UEChMQRXhhbXBsZSBPcmcsIExMQzEa
MBgGA1UECxMRU2VydmVyIE9wZXJhdGlvbnMwXDANBgkqhkiG9w0BAQEFAANLADBI
AkEAvo/az3oR69SP92jGnUHMJLEyyD1Ui1BZ/rUABJcQTRQqn3RqtlfYePWZnUaZ
srKbXRS4q0w5Vqf1kx5w3q5tIwIDAQABo4GcMIGZMHkGA1UdIwRyMHCAFDBN1mqO
Nc4gUraE4zRtw6ueFDDaoU2kSzBJMRAwDgYDVQQDDAdSb290IENBMRowGAYDVQQL
DBFTZXJ2ZXIgT3BlcmF0aW9uczEZMBcGA1UECgwQRXhhbXBsZSBPcmcsIExMQ4IJ
ALf2Pk2HvtBzMA8GA1UdEwEB/wQFMAMBAf8wCwYDVR0PBAQDAgEGMA0GCSqGSIb3
DQEBBQUAA4GBACRfa1YPS7RQUuhYovGgV0VYqxuATC7WwdIRihVh5FceSXKgSIbz
BKmOBAy/KixEhpnHTbkpaJ0d9ITkvjMTmj3M5YMahKaQA5niVPckQPecMMd6jg9U
l1k75xLLIcrlsDYo3999KOSSchH2K7bLT7TuQ2okdP6FHWmeWmudewlu
-----END CERTIFICATE-----
    MASTER_CA
  end

  def agent_ca
    <<-AGENT_CA
-----BEGIN CERTIFICATE-----
MIIClTCCAf6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBJMRAwDgYDVQQDDAdSb290
IENBMRowGAYDVQQLDBFTZXJ2ZXIgT3BlcmF0aW9uczEZMBcGA1UECgwQRXhhbXBs
ZSBPcmcsIExMQzAeFw0xMzAzMzAwNTUwNDhaFw0zMzAzMjUwNTUwNDhaMH0xIzAh
BgNVBAMTGkludGVybWVkaWF0ZSBDQSAoYWdlbnQtY2EpMR8wHQYJKoZIhvcNAQkB
FhB0ZXN0QGV4YW1wbGUub3JnMRkwFwYDVQQKExBFeGFtcGxlIE9yZywgTExDMRow
GAYDVQQLExFTZXJ2ZXIgT3BlcmF0aW9uczBcMA0GCSqGSIb3DQEBAQUAA0sAMEgC
QQDkEj/Msmi4hJImxP5+ocixMTHuYC1M1E2p4QcuzOkZYrfHf+5hJMcahfYhLiXU
jHBredOXhgSisHh6CLSb/rKzAgMBAAGjgZwwgZkweQYDVR0jBHIwcIAUME3Wao41
ziBStoTjNG3Dq54UMNqhTaRLMEkxEDAOBgNVBAMMB1Jvb3QgQ0ExGjAYBgNVBAsM
EVNlcnZlciBPcGVyYXRpb25zMRkwFwYDVQQKDBBFeGFtcGxlIE9yZywgTExDggkA
t/Y+TYe+0HMwDwYDVR0TAQH/BAUwAwEB/zALBgNVHQ8EBAMCAQYwDQYJKoZIhvcN
AQEFBQADgYEAujSj9rxIxJHEuuYXb15L30yxs9Tdvy4OCLiKdjvs9Z7gG8Pbutls
ooCwyYAkmzKVs/8cYjZJnvJrPEW1gFwqX7Xknp85Cfrl+/pQEPYq5sZVa5BIm9tI
0EvlDax/Hd28jI6Bgq5fsTECNl9GDGknCy7vwRZem0h+hI56lzR3pYE=
-----END CERTIFICATE-----
    AGENT_CA
  end

  # Signed by the master CA (Good)
  def master_issued_by_master_ca
<<-GOOD_SSL_CERT
-----BEGIN CERTIFICATE-----
MIICZzCCAhGgAwIBAgIBATANBgkqhkiG9w0BAQUFADB+MSQwIgYDVQQDExtJbnRl
cm1lZGlhdGUgQ0EgKG1hc3Rlci1jYSkxHzAdBgkqhkiG9w0BCQEWEHRlc3RAZXhh
bXBsZS5vcmcxGTAXBgNVBAoTEEV4YW1wbGUgT3JnLCBMTEMxGjAYBgNVBAsTEVNl
cnZlciBPcGVyYXRpb25zMB4XDTEzMDMzMDA1NTA0OFoXDTMzMDMyNTA1NTA0OFow
HjEcMBoGA1UEAwwTbWFzdGVyMS5leGFtcGxlLm9yZzBcMA0GCSqGSIb3DQEBAQUA
A0sAMEgCQQDACW8fryVZH0dC7vYUASonVBKYcILnKN2O9QX7RenZGN1TWek9LQxr
yQFDyp7WJ8jUw6nENGniLU8J+QSSxryjAgMBAAGjgdkwgdYwWwYDVR0jBFQwUqFN
pEswSTEQMA4GA1UEAwwHUm9vdCBDQTEaMBgGA1UECwwRU2VydmVyIE9wZXJhdGlv
bnMxGTAXBgNVBAoMEEV4YW1wbGUgT3JnLCBMTEOCAQIwDAYDVR0TAQH/BAIwADAL
BgNVHQ8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMD0GA1Ud
EQQ2MDSCE21hc3RlcjEuZXhhbXBsZS5vcmeCB21hc3RlcjGCBnB1cHBldIIMcHVw
cGV0bWFzdGVyMA0GCSqGSIb3DQEBBQUAA0EAo8PvgLrah6jQVs6YCBxOTn13PDip
fVbcRsFd0dtIr00N61bCqr6Fa0aRwy424gh6bVJTNmk2zoaH7r025dZRhw==
-----END CERTIFICATE-----
GOOD_SSL_CERT
  end

  # Signed by the agent CA, not the master CA (Rogue)
  def master_issued_by_agent_ca
<<-BAD_SSL_CERT
-----BEGIN CERTIFICATE-----
MIICZjCCAhCgAwIBAgIBBDANBgkqhkiG9w0BAQUFADB9MSMwIQYDVQQDExpJbnRl
cm1lZGlhdGUgQ0EgKGFnZW50LWNhKTEfMB0GCSqGSIb3DQEJARYQdGVzdEBleGFt
cGxlLm9yZzEZMBcGA1UEChMQRXhhbXBsZSBPcmcsIExMQzEaMBgGA1UECxMRU2Vy
dmVyIE9wZXJhdGlvbnMwHhcNMTMwMzMwMDU1MDQ4WhcNMzMwMzI1MDU1MDQ4WjAe
MRwwGgYDVQQDDBNtYXN0ZXIxLmV4YW1wbGUub3JnMFwwDQYJKoZIhvcNAQEBBQAD
SwAwSAJBAPnCDnryLLXWepGLqsdBWlytfeakE/yijM8GlE/yT0SbpJInIhJR1N1A
0RskriHrxTU5qQEhd0RIja7K5o4NYksCAwEAAaOB2TCB1jBbBgNVHSMEVDBSoU2k
SzBJMRAwDgYDVQQDDAdSb290IENBMRowGAYDVQQLDBFTZXJ2ZXIgT3BlcmF0aW9u
czEZMBcGA1UECgwQRXhhbXBsZSBPcmcsIExMQ4IBATAMBgNVHRMBAf8EAjAAMAsG
A1UdDwQEAwIFoDAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwPQYDVR0R
BDYwNIITbWFzdGVyMS5leGFtcGxlLm9yZ4IHbWFzdGVyMYIGcHVwcGV0ggxwdXBw
ZXRtYXN0ZXIwDQYJKoZIhvcNAQEFBQADQQA841IzHLlnn4RIJ0/BOZ/16iWC1dNr
jV9bELC5OxeMNSsVXbFNeTHwbHEYjDg5dQ6eUkxPdBSMWBeQwe2Mw+xG
-----END CERTIFICATE-----
BAD_SSL_CERT
  end

  def cert_chain
    [ master_issued_by_master_ca, master_ca, root_ca ].map do |pem|
      OpenSSL::X509::Certificate.new(pem)
    end
  end

  def cert_chain_agent_ca
    [ master_issued_by_agent_ca, agent_ca, root_ca ].map do |pem|
      OpenSSL::X509::Certificate.new(pem)
    end
  end

  def cert_chain_in_callback_order
    cert_chain.reverse
  end

  let :authz_error_prefix do
    "The server presented a SSL certificate chain which does not include a CA listed in the ssl_client_ca_auth file.  "
  end

  let :expected_authz_error_msg do
    authz_ca_certs = ssl_configuration.ca_auth_certificates
    msg = authz_error_prefix
    msg << "Authorized Issuers: #{authz_ca_certs.collect {|c| c.subject}.join(', ')}  "
    msg << "Peer Chain: #{cert_chain.collect {|c| c.subject}.join(' => ')}"
    msg
  end

  let :root_ca_cert do
    OpenSSL::X509::Certificate.new(root_ca)
  end

  let :master_ca_cert do
    OpenSSL::X509::Certificate.new(master_ca)
  end

  let :agent_ca_cert do
    OpenSSL::X509::Certificate.new(agent_ca)
  end
end
