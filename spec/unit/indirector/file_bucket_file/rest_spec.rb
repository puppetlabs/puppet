require 'spec_helper'

require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucketFile::Rest do
  let(:rest_path) {"filebucket://xanadu:8141/"}
  let(:file_bucket_file) {Puppet::FileBucket::File.new('file contents', :bucket_path => '/some/random/path')}
  let(:files_original_path) {'/path/to/file'}
  let(:dest_path) {"#{rest_path}#{file_bucket_file.name}/#{files_original_path}"}
  let(:file_bucket_path) {"#{rest_path}#{file_bucket_file.checksum_type}/#{file_bucket_file.checksum_data}/#{files_original_path}"}
  let(:source_path) {"#{rest_path}#{file_bucket_file.checksum_type}/#{file_bucket_file.checksum_data}"}

  let(:uri) { %r{/puppet/v3/file_bucket_file} }

  describe '#head' do
    it 'includes the environment as a request parameter' do
      stub_request(:head, uri).with(query: hash_including(environment: 'outerspace'))

      described_class.indirection.head(file_bucket_path, :bucket_path => file_bucket_file.bucket_path, environment: Puppet::Node::Environment.remote('outerspace'))
    end

    it 'includes bucket path in the request if bucket path is set' do
      stub_request(:head, uri).with(query: hash_including(bucket_path: '/some/random/path'))

      described_class.indirection.head(file_bucket_path, :bucket_path => file_bucket_file.bucket_path)
    end

    it "returns nil on 404" do
      stub_request(:head, uri).to_return(status: 404)

      expect(described_class.indirection.head(file_bucket_path, :bucket_path => file_bucket_file.bucket_path)).to be_falsy
    end

    it "raises for all other fail codes" do
      stub_request(:head, uri).to_return(status: [503, 'server unavailable'])

      expect{described_class.indirection.head(file_bucket_path, :bucket_path => file_bucket_file.bucket_path)}.to raise_error(Net::HTTPError, "Error 503 on SERVER: server unavailable")
    end
  end

  describe '#find' do
    it 'includes the environment as a request parameter' do
      stub_request(:get, uri).with(query: hash_including(environment: 'outerspace')).to_return(status: 200, headers: {'Content-Type' => 'application/octet-stream'})

      described_class.indirection.find(source_path, :bucket_path => nil, environment: Puppet::Node::Environment.remote('outerspace'))
    end

    {bucket_path: 'path', diff_with: '4aabe1257043bd0', list_all: 'true', fromdate: '20200404', todate: '20200404'}.each do |param, val|
      it "includes #{param} as a parameter in the request if #{param} is set" do
        stub_request(:get, uri).with(query: hash_including(param => val)).to_return(status: 200, headers: {'Content-Type' => 'application/octet-stream'})

        options = { param => val }
        described_class.indirection.find(source_path, **options)
      end
    end

    it 'raises if unsuccessful' do
      stub_request(:get, uri).to_return(status: [503, 'server unavailable'])

      expect{described_class.indirection.find(source_path, :bucket_path => nil)}.to raise_error(Net::HTTPError, "Error 503 on SERVER: server unavailable")
    end

    it 'raises if Content-Type is not included in the response' do
      stub_request(:get, uri).to_return(status: 200, headers: {})

      expect{described_class.indirection.find(source_path, :bucket_path => nil)}.to raise_error(RuntimeError, "No content type in http response; cannot parse")
    end
  end

  describe '#save' do
    it 'includes the environment as a request parameter' do
      stub_request(:put, uri).with(query: hash_including(environment: 'outerspace'))

      described_class.indirection.save(file_bucket_file, dest_path, environment: Puppet::Node::Environment.remote('outerspace'))
    end

    it 'sends the contents of the file as the request body' do
      stub_request(:put, uri).with(body: file_bucket_file.contents)

      described_class.indirection.save(file_bucket_file, dest_path)
    end

    it 'raises if unsuccessful' do
      stub_request(:put, uri).to_return(status: [503, 'server unavailable'])

      expect{described_class.indirection.save(file_bucket_file, dest_path)}.to raise_error(Net::HTTPError, "Error 503 on SERVER: server unavailable")
    end
  end
end
