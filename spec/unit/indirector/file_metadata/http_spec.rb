require 'spec_helper'

require 'puppet/indirector/file_metadata'
require 'puppet/indirector/file_metadata/http'

describe Puppet::Indirector::FileMetadata::Http do
  DEFAULT_HEADERS = {
    "Cache-Control" => "private, max-age=0",
    "Connection" => "close",
    "Content-Encoding" => "gzip",
    "Content-Type" => "text/html; charset=ISO-8859-1",
    "Date" => "Fri, 01 May 2020 17:16:00 GMT",
    "Expires" => "-1",
    "Server" => "gws"
  }.freeze

  let(:certname) { 'ziggy' }
  # The model is Puppet:FileServing::Metadata
  let(:model) { described_class.model }
  # The http terminus creates instances of HttpMetadata which subclass Metadata
  let(:metadata) { Puppet::FileServing::HttpMetadata.new(key) }
  let(:key) { "https://example.com/path/to/file" }
  # Digest::MD5.base64digest("") => "1B2M2Y8AsgTpgAmY7PhCfg=="
  let(:content_md5) { {"Content-MD5" => "1B2M2Y8AsgTpgAmY7PhCfg=="} }
  let(:last_modified) { {"Last-Modified" => "Wed, 01 Jan 2020 08:00:00 GMT"} }

  before :each do
    described_class.indirection.terminus_class = :http
  end

  context "when finding" do
    it "returns http file metadata" do
      stub_request(:head, key)
        .to_return(status: 200, headers: DEFAULT_HEADERS)

      result = model.indirection.find(key)
      expect(result.ftype).to eq('file')
      expect(result.path).to eq('/dev/null')
      expect(result.relative_path).to be_nil
      expect(result.destination).to be_nil
      expect(result.checksum).to match(%r{mtime})
      expect(result.owner).to be_nil
      expect(result.group).to be_nil
      expect(result.mode).to be_nil
    end

    it "reports an md5 checksum if present in the response" do
      stub_request(:head, key)
        .to_return(status: 200, headers: DEFAULT_HEADERS.merge(content_md5))

      result = model.indirection.find(key)
      expect(result.checksum_type).to eq(:md5)
      expect(result.checksum).to eq("{md5}d41d8cd98f00b204e9800998ecf8427e")
    end

    it "reports an mtime checksum if present in the response" do
      stub_request(:head, key)
        .to_return(status: 200, headers: DEFAULT_HEADERS.merge(last_modified))

      result = model.indirection.find(key)
      expect(result.checksum_type).to eq(:mtime)
      expect(result.checksum).to eq("{mtime}2020-01-01 08:00:00 UTC")
    end

    it "prefers md5" do
      stub_request(:head, key)
        .to_return(status: 200, headers: DEFAULT_HEADERS.merge(content_md5).merge(last_modified))

      result = model.indirection.find(key)
      expect(result.checksum_type).to eq(:md5)
      expect(result.checksum).to eq("{md5}d41d8cd98f00b204e9800998ecf8427e")
    end

    it "prefers mtime when explicitly requested" do
      stub_request(:head, key)
        .to_return(status: 200, headers: DEFAULT_HEADERS.merge(content_md5).merge(last_modified))

      result = model.indirection.find(key, checksum_type: :mtime)
      expect(result.checksum_type).to eq(:mtime)
      expect(result.checksum).to eq("{mtime}2020-01-01 08:00:00 UTC")
    end

    it "leniently parses base64" do
      # Content-MD5 header is missing '==' padding
      stub_request(:head, key)
        .to_return(status: 200, headers: DEFAULT_HEADERS.merge("Content-MD5" => "1B2M2Y8AsgTpgAmY7PhCfg"))

      result = model.indirection.find(key)
      expect(result.checksum_type).to eq(:md5)
      expect(result.checksum).to eq("{md5}d41d8cd98f00b204e9800998ecf8427e")
    end

    it "URL encodes special characters" do
      pending("HTTP terminus doesn't encode the URI before parsing")

      stub_request(:head, %r{/path%20to%20file})

      model.indirection.find('https://example.com/path to file')
    end

    it "sends query parameters" do
      stub_request(:head, key).with(query: {'a' => 'b'})

      model.indirection.find("#{key}?a=b")
    end

    it "returns nil if the content doesn't exist" do
      stub_request(:head, key).to_return(status: 404)

      expect(model.indirection.find(key)).to be_nil
    end

    it "returns nil if fail_on_404" do
      stub_request(:head, key).to_return(status: 404)

      expect(model.indirection.find(key, fail_on_404: true)).to be_nil
    end

    it "returns nil on HTTP 500" do
      stub_request(:head, key).to_return(status: 500)

      # this is kind of strange, but it does allow puppet to try
      # multiple `source => ["URL1", "URL2"]` and use the first
      # one based on sourceselect
      expect(model.indirection.find(key)).to be_nil
    end

    it "accepts all content types" do
      stub_request(:head, key).with(headers: {'Accept' => '*/*'})

      model.indirection.find(key)
    end

    it "sets puppet user-agent" do
      stub_request(:head, key).with(headers: {'User-Agent' => Puppet[:http_user_agent]})

      model.indirection.find(key)
    end

    it "tries to persist the connection" do
      # HTTP/1.1 defaults to persistent connections, so check for
      # the header's absence
      stub_request(:head, key).with do |request|
        expect(request.headers).to_not include('Connection')
      end

      model.indirection.find(key)
    end

    it "follows redirects" do
      new_url = "https://example.com/different/path"
      redirect = { status: 200, headers: { 'Location' => new_url }, body: ""}
      stub_request(:head, key).to_return(redirect)
      stub_request(:head, new_url)

      model.indirection.find(key)
    end

    it "falls back to partial GET if HEAD is not allowed" do
      stub_request(:head, key)
        .to_return(status: 405)
      stub_request(:get, key)
        .to_return(status: 200, headers: {'Range' => 'bytes=0-0'})

      model.indirection.find(key)
    end

    context "AWS" do
      it "falls back to a partial GET" do
        stub_request(:head, key)
          .to_return(status: 403, headers: DEFAULT_HEADERS.merge({ "x-amz-request-id" => "EA308572DC91B4EA"}))
        stub_request(:get, key)
          .to_return(status: 200, headers: {'Range' => 'bytes=0-0'})

        model.indirection.find(key)
      end

      it "returns nil if the GET fails" do
        stub_request(:head, key)
          .to_return(status: 403, headers: DEFAULT_HEADERS.merge({ "x-amz-request-id" => "EA308572DC91B4EA"}))
        stub_request(:get, key)
          .to_return(status: 403)

        expect(model.indirection.find(key)).to be_nil
      end
    end
  end

  context "when searching" do
    it "raises an error" do
      expect {
        model.indirection.search(key)
      }.to raise_error(Puppet::Error, 'cannot lookup multiple files')
    end
  end
end
