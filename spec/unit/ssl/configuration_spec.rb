#! /usr/bin/env ruby
#

require 'spec_helper'
require 'puppet/ssl/configuration'

describe Puppet::SSL::Configuration do
  let(:localcacert) { "/path/to/certs/ca.pem" }

  let(:ssl_server_ca_auth) { "/path/to/certs/ssl_server_ca_auth.pem" }

  it "should require the localcacert argument" do
    expect { subject }.to raise_error ArgumentError
  end

  context "Default configuration" do
    subject do
      described_class.new(localcacert)
    end

    it "#ca_chain_file == localcacert" do
      expect(subject.ca_chain_file).to eq(localcacert)
    end

    it "#ca_auth_file == localcacert" do
      expect(subject.ca_auth_file).to eq(localcacert)
    end
  end

  context "Explicitly configured" do
    subject do
      options = {
        :ca_auth_file  => ssl_server_ca_auth,
      }
      Puppet::SSL::Configuration.new(localcacert, options)
    end

    it "#ca_chain_file == ssl_server_ca_chain" do
      expect(subject.ca_chain_file).to eq(ssl_server_ca_auth)
    end

    it "#ca_auth_file == ssl_server_ca_auth" do
      expect(subject.ca_auth_file).to eq(ssl_server_ca_auth)
    end

    it "#ca_auth_certificates returns an Array<OpenSSL::X509::Certificate>" do
      subject.stubs(:read_file).returns(master_ca_pem + root_ca_pem)

      certs = subject.ca_auth_certificates
      certs.each { |cert| expect(cert).to be_a_kind_of OpenSSL::X509::Certificate }
    end
  end

  context "Partially configured" do
    describe "#ca_chain_file" do
      subject do
        described_class.new(localcacert, { :ca_auth_file => ssl_server_ca_auth })
      end

      it "should use ca_auth_file" do
        expect(subject.ca_chain_file).to eq(ssl_server_ca_auth)
      end
    end
  end

  # This is the Intermediate CA specifically designated for issuing master
  # certificates.  It is signed by the Root CA.
  def master_ca_pem
    @master_ca_pem ||= <<-AUTH_BUNDLE
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
    AUTH_BUNDLE
  end

  # This is the Root CA
  def root_ca_pem
    @root_ca_pem ||= <<-LOCALCACERT
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
    LOCALCACERT
  end

  # This is the intermediate CA designated to issue Agent SSL certs.  It is
  # signed by the Root CA.
  def agent_ca_pem
    @agent_ca_pem ||= <<-AGENT_CA
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
end
