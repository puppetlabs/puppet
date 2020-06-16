require 'spec_helper'
require 'puppet/http'

describe Puppet::HTTP::Response do
  let(:uri) { URI.parse('https://www.example.com') }
  let(:client) { Puppet::HTTP::Client.new }

  it "returns the request URL" do
    stub_request(:get, uri)

    response = client.get(uri)
    expect(response.url).to eq(uri)
  end

  it "returns the HTTP code" do
    stub_request(:get, uri)

    response = client.get(uri)
    expect(response.code).to eq(200)
  end

  it "returns the HTTP reason string" do
    stub_request(:get, uri).to_return(status: [418, "I'm a teapot"])

    response = client.get(uri)
    expect(response.reason).to eq("I'm a teapot")
  end

  it "returns the response body" do
    stub_request(:get, uri).to_return(status: 200, body: "I'm the body")

    response = client.get(uri)
    expect(response.body).to eq("I'm the body")
  end

  it "streams the response body" do
    stub_request(:get, uri).to_return(status: 200, body: "I'm the streaming body")

    content = StringIO.new
    client.get(uri) do |response|
      response.read_body do |data|
        content << data
      end
    end
    expect(content.string).to eq("I'm the streaming body")
  end

  it "raises if a block isn't given when streaming" do
    stub_request(:get, uri).to_return(status: 200, body: "")

    expect {
      client.get(uri) do |response|
        response.read_body
      end
    }.to raise_error(Puppet::HTTP::HTTPError, %r{Request to https://www.example.com failed after .* seconds: A block is required})
  end

  it "returns success for all 2xx codes" do
    stub_request(:get, uri).to_return(status: 202)

    expect(client.get(uri)).to be_success
  end

  it "returns a header value" do
    stub_request(:get, uri).to_return(status: 200, headers: { 'Content-Encoding' => 'gzip' })

    expect(client.get(uri)['Content-Encoding']).to eq('gzip')
  end

  it "enumerates headers" do
    stub_request(:get, uri).to_return(status: 200, headers: { 'Content-Encoding' => 'gzip' })

    expect(client.get(uri).each_header.to_a).to eq([['content-encoding', 'gzip']])
  end
end
