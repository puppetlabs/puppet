require 'spec_helper'

require 'puppet/indirector/file_content/rest'

describe Puppet::Indirector::FileContent::Rest do
  let(:certname) { 'ziggy' }
  let(:uri) { %r{/puppet/v3/file_content/:mount/path/to/file} }
  let(:key) { "puppet:///:mount/path/to/file" }

  before :each do
    described_class.indirection.terminus_class = :rest
  end

  def file_content_response
    {body: "some content", headers: { 'Content-Type' => 'application/octet-stream' } }
  end

  it "returns content as a binary string" do
    stub_request(:get, uri).to_return(status: 200, **file_content_response)

    file_content = described_class.indirection.find(key)
    expect(file_content.content.encoding).to eq(Encoding::BINARY)
    expect(file_content.content).to eq('some content')
  end

  it "URL encodes special characters" do
    stub_request(:get, %r{/puppet/v3/file_content/:mount/path%20to%20file}).to_return(status: 200, **file_content_response)

    described_class.indirection.find('puppet:///:mount/path to file')
  end

  it "returns nil if the content doesn't exist" do
    stub_request(:get, uri).to_return(status: 404)

    expect(described_class.indirection.find(key)).to be_nil
  end

  it "raises if fail_on_404 is true" do
    stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json'}, body: "{}")

    expect {
      described_class.indirection.find(key, fail_on_404: true)
    }.to raise_error(Puppet::Error, %r{Find /puppet/v3/file_content/:mount/path/to/file resulted in 404 with the message: {}})
  end

  it "raises an error on HTTP 500" do
    stub_request(:get, uri).to_return(status: 500, headers: { 'Content-Type' => 'application/json'}, body: "{}")

    expect {
      described_class.indirection.find(key)
    }.to raise_error(Net::HTTPError, %r{Error 500 on SERVER: })
  end

  it "connects to a specific host" do
    stub_request(:get, %r{https://example.com:8140/puppet/v3/file_content/:mount/path/to/file})
      .to_return(status: 200, **file_content_response)

    described_class.indirection.find("puppet://example.com:8140/:mount/path/to/file")
  end
end
