require 'spec_helper'

require 'puppet/indirector/file_metadata'
require 'puppet/indirector/file_metadata/rest'

describe Puppet::Indirector::FileMetadata::Rest do
  let(:certname) { 'ziggy' }
  let(:formatter) { Puppet::Network::FormatHandler.format(:json) }
  let(:model) { described_class.model }

  before :each do
    described_class.indirection.terminus_class = :rest
  end

  def metadata_response(metadata)
    { body: formatter.render(metadata), headers: {'Content-Type' => formatter.mime } }
  end

  context "when finding" do
    let(:uri) { %r{/puppet/v3/file_metadata/:mount/path/to/file} }
    let(:key) { "puppet:///:mount/path/to/file" }
    let(:metadata) { model.new('/path/to/file') }

    it "returns file metadata" do
      stub_request(:get, uri)
        .to_return(status: 200, **metadata_response(metadata))

      result = model.indirection.find(key)
      expect(result.path).to eq('/path/to/file')
    end

    it "URL encodes special characters" do
      stub_request(:get, %r{/puppet/v3/file_metadata/:mount/path%20to%20file})
        .to_return(status: 200, **metadata_response(metadata))

      model.indirection.find('puppet:///:mount/path to file')
    end

    it "returns nil if the content doesn't exist" do
      stub_request(:get, uri).to_return(status: 404)

      expect(model.indirection.find(key)).to be_nil
    end

    it "raises if fail_on_404 is true" do
      stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json'}, body: "{}")

      expect {
        model.indirection.find(key, fail_on_404: true)
      }.to raise_error(Puppet::Error, %r{Find /puppet/v3/file_metadata/:mount/path/to/file resulted in 404 with the message: {}})
    end

    it "raises an error on HTTP 500" do
      stub_request(:get, uri).to_return(status: 500, headers: { 'Content-Type' => 'application/json'}, body: "{}")

      expect {
        model.indirection.find(key)
      }.to raise_error(Net::HTTPError, %r{Error 500 on SERVER: })
    end

    it "connects to a specific host" do
      stub_request(:get, %r{https://example.com:8140/puppet/v3/file_metadata/:mount/path/to/file})
        .to_return(status: 200, **metadata_response(metadata))

      model.indirection.find("puppet://example.com:8140/:mount/path/to/file")
    end
  end

  context "when searching" do
    let(:uri) { %r{/puppet/v3/file_metadatas/:mount/path/to/dir} }
    let(:key) { "puppet:///:mount/path/to/dir" }
    let(:metadatas) { [model.new('/path/to/dir')] }

    it "returns an array of file metadata" do
      stub_request(:get, uri)
        .to_return(status: 200, **metadata_response(metadatas))

      result = model.indirection.search(key)
      expect(result.first.path).to eq('/path/to/dir')
    end

    it "URL encodes special characters" do
      stub_request(:get, %r{/puppet/v3/file_metadatas/:mount/path%20to%20dir})
        .to_return(status: 200, **metadata_response(metadatas))

      model.indirection.search('puppet:///:mount/path to dir')
    end

    it "returns an empty array if the metadata doesn't exist" do
      stub_request(:get, uri).to_return(status: 404)

      expect(model.indirection.search(key)).to eq([])
    end

    it "returns an empty array if the metadata doesn't exist and fail_on_404 is true" do
      stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json'}, body: "{}")

      expect(model.indirection.search(key, fail_on_404: true)).to eq([])
    end

    it "raises an error on HTTP 500" do
      stub_request(:get, uri).to_return(status: 500, headers: { 'Content-Type' => 'application/json'}, body: "{}")

      expect {
        model.indirection.search(key)
      }.to raise_error(Net::HTTPError, %r{Error 500 on SERVER: })
    end

    it "connects to a specific host" do
      stub_request(:get, %r{https://example.com:8140/puppet/v3/file_metadatas/:mount/path/to/dir})
        .to_return(status: 200, **metadata_response(metadatas))

      model.indirection.search("puppet://example.com:8140/:mount/path/to/dir")
    end
  end
end
