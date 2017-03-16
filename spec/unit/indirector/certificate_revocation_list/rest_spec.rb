#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate_revocation_list/rest'

describe Puppet::SSL::CertificateRevocationList::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    expect(Puppet::SSL::CertificateRevocationList::Rest.superclass).to equal(Puppet::Indirector::REST)
  end

  it "should set server_setting to :ca_server" do
    expect(Puppet::SSL::CertificateRevocationList::Rest.server_setting).to eq(:ca_server)
  end

  it "should set port_setting to :ca_port" do
    expect(Puppet::SSL::CertificateRevocationList::Rest.port_setting).to eq(:ca_port)
  end

  it "should use the :ca SRV service" do
    expect(Puppet::SSL::CertificateRevocationList::Rest.srv_service).to eq(:ca)
  end

  context '#find' do
    let(:request) { Puppet::Indirector::Request.new(:certificate_revocation_list, :find, "ca", nil) }

    let(:network) { stub('network') }

    let(:crl_pem) do
      <<-EOD
-----BEGIN X509 CRL-----
MIICpzCBkAIBATANBgkqhkiG9w0BAQUFADAtMSswKQYDVQQDDCJQdXBwZXQgQ0E6
IHNreS5jb3JwLnB1cHBldGxhYnMubmV0Fw0xNzAyMjMxNzM1MjlaFw0yMjAyMjIx
NzM1MzBaoC8wLTAfBgNVHSMEGDAWgBRyopc/gCX4zlAFtkdl4+b4tg4QcjAKBgNV
HRQEAwIBADANBgkqhkiG9w0BAQUFAAOCAgEAdSarUvDk3PZfkdpRKuee3Ye12llg
Cv6YiJWPfcxSo4mjnzoB6Bzu475pR7RvltrVQDIhCQ0pa6LK6pYOD6mntdDNuQfP
IGOoHv3657wz6fVBxA7f97XNZvctBt4+mAd3XjCEFBpWBZ8pNFph827W+cTXX8oI
5RXnN4G2EupPubBPYwVA3Hqq/ICuDnhfJmzNuhUs7Y2Oi+Wcejf6UAmD9RiYn3u8
z+PilDdtuiEik3Wii8o3t+n6PgC/wmeTpoeUs4A/lo8VETbLttTA5gERftNt/XH7
6ccy4tkGsr+b6Dy4Q00Y2dbeJelLf51ON5ccaMCjn27FDYciI8thhBNDxPrDoq4f
9ObE3qQyqH+gZ6vr1dJ5N1gRYU1f0XIS+xGJu2Q29pmJMEGRS1MklKSeEYFPHFM4
Zbb3g+9FVdUeLca1w9UFGd513R9uAsFxvAmOQ9ntJNx/TL44zbSA1JcZPa8GI1ma
s2E5zWT0UzEMliR65M6ZqVFJ6/z8D7uVlYcXHclndUmBnxCAgbaf43/54HO+dR2K
yPiyYYELiVCcAv6/zcujENwSXLFBjvpn3x11sW7ojKWQBwG5aPMR/ndH6Jy4iJgm
Hv6DLA3zfYCQx2KgD/mAoosyekk5YZm0LuwNb7Hbutab14AQzyMIanYGF3sKS9KY
eIUcJk0FgZTRQ4I=
-----END X509 CRL-----
      EOD
    end

    let(:response) do
      response = stub 'response', :code => "200", :body => crl_pem
      response.stubs(:[]).with('content-type').returns "text/plain"
      response.stubs(:[]).with('content-encoding')
      response.stubs(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).returns(Puppet.version)
      response
    end

    it "overrides the certificate revocation status when fetching the ca crl and no CRL is present" do
      subject.expects(:network).returns(network)
      network.expects(:get).with do |args|
        # Ensure that revocation is disabled when the HTTP request would be made
        expect(Puppet.lookup(:certificate_revocation)).to be_falsey
      end.returns(response)

      marker = stub('CRL revocation bool')
      Puppet.override({certificate_revocation: marker}) do
        subject.find(request)
        expect(Puppet.lookup(:certificate_revocation)).to eq marker
      end
    end
  end
end
