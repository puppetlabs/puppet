#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate/rest'

describe Puppet::SSL::Certificate::Rest do
  before do
    @searcher = Puppet::SSL::Certificate::Rest.new
  end

  it "should be a sublcass of Puppet::Indirector::REST" do
    expect(Puppet::SSL::Certificate::Rest.superclass).to equal(Puppet::Indirector::REST)
  end

  it "should set server_setting to :ca_server" do
    expect(Puppet::SSL::Certificate::Rest.server_setting).to eq(:ca_server)
  end

  it "should set port_setting to :ca_port" do
    expect(Puppet::SSL::Certificate::Rest.port_setting).to eq(:ca_port)
  end

  it "should use the :ca SRV service" do
    expect(Puppet::SSL::Certificate::Rest.srv_service).to eq(:ca)
  end

  it "should make sure found certificates have their names set to the search string" do
    terminus = Puppet::SSL::Certificate::Rest.new

    # This has 'boo.com' in the CN
    cert_string = "-----BEGIN CERTIFICATE-----
MIICPzCCAaigAwIBAgIBBDANBgkqhkiG9w0BAQUFADAWMRQwEgYDVQQDDAtidWNr
eS5sb2NhbDAeFw0wOTA5MTcxNzI1MzJaFw0xNDA5MTYxNzI1MzJaMBIxEDAOBgNV
BAMMB2Jvby5jb20wgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAKG9B+DkTCNh
F5xHchNDfnbC9NzWKM600oxrr84pgUVAG6B2wAZcdfoEtXszhsY9Jzpwqkvxk4Mx
AbYqo9+TCi4UoiH6e+vAKOOJD3DHrlf+/RW4hGtyaI41DBhf4+B4/oFz5PH9mvKe
NSfHFI/yPW+1IXYjxKLQNwF9E7q3JbnzAgMBAAGjgaAwgZ0wOAYJYIZIAYb4QgEN
BCsWKVB1cHBldCBSdWJ5L09wZW5TU0wgR2VuZXJhdGVkIENlcnRpZmljYXRlMAwG
A1UdEwEB/wQCMAAwHQYDVR0OBBYEFJOxEUeyf4cNOBmf9zIaE1JTuNdLMAsGA1Ud
DwQEAwIFoDAnBgNVHSUEIDAeBggrBgEFBQcDAQYIKwYBBQUHAwIGCCsGAQUFBwME
MA0GCSqGSIb3DQEBBQUAA4GBAFTJxKprMg6tfhGnvEvURPmlJrINn9c2b5Y4AGYp
tO86PFFkWw/EIJvvJzbj3s+Butr+eUo//+f1xxX7UCwwGqGxKqjtVS219oU/wkx8
h7rW4Xk7MrLl0auSS1p4wLcAMm+ZImf94+j8Cj+tkr8eGozZceRV13b8+EkdaE3S
rn/G
-----END CERTIFICATE-----
"

    network = stub 'network'
    terminus.stubs(:network).returns network

    response = stub 'response', :code => "200", :body => cert_string
    response.stubs(:[]).with('content-type').returns "text/plain"
    response.stubs(:[]).with('content-encoding')
    response.stubs(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).returns(Puppet.version)
    network.stubs(:verify_callback=)
    network.expects(:get).returns response

    request = Puppet::Indirector::Request.new(:certificate, :find, "foo.com", nil)
    result = terminus.find(request)
    expect(result).not_to be_nil
    expect(result.name).to eq("foo.com")
  end
end
