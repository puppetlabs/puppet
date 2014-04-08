# encoding: utf-8
require 'spec_helper'
require 'puppet/forge'
require 'net/http'
require 'puppet/module_tool'

describe Puppet::Forge::ModuleRelease do
  let(:agent) { "Test/1.0" }
  let(:repository) { Puppet::Forge::Repository.new('http://fake.com', agent) }
  let(:ssl_repository) { Puppet::Forge::Repository.new('https://fake.com', agent) }

  let(:release_json) do
  <<-EOF
  {
    "uri": "/v3/releases/puppetlabs-stdlib-4.1.0",
    "module": {
      "uri": "/v3/modules/puppetlabs-stdlib",
      "name": "stdlib",
      "owner": {
        "uri": "/v3/users/puppetlabs",
        "username": "puppetlabs",
        "gravatar_id": "fdd009b7c1ec96e088b389f773e87aec"
      }
    },
    "version": "4.1.0",
    "metadata": {
      "types": [ ],
      "license": "Apache 2.0",
      "checksums": { },
      "version": "4.1.0",
      "description": "Standard Library for Puppet Modules",
      "source": "git://github.com/puppetlabs/puppetlabs-stdlib.git",
      "project_page": "https://github.com/puppetlabs/puppetlabs-stdlib",
      "summary": "Puppet Module Standard Library",
      "dependencies": [

      ],
      "author": "puppetlabs",
      "name": "puppetlabs-stdlib"
    },
    "tags": [
      "puppetlabs",
      "library",
      "stdlib",
      "standard",
      "stages"
    ],
    "file_uri": "/v3/files/puppetlabs-stdlib-4.1.0.tar.gz",
    "file_size": 67586,
    "file_md5": "bbf919d7ee9d278d2facf39c25578bf8",
    "downloads": 610751,
    "readme": "",
    "changelog": "",
    "license": "",
    "created_at": "2013-05-13 08:31:19 -0700",
    "updated_at": "2013-05-13 08:31:19 -0700",
    "deleted_at": null
  }
  EOF
  end

  let(:release) { Puppet::Forge::ModuleRelease.new(ssl_repository, JSON.parse(release_json)) }

  let(:mock_file) {
    mock_io = StringIO.new
    mock_io.stubs(:path).returns('/dev/null')
    mock_io
  }

  let(:mock_dir) { '/tmp' }

  def mock_digest_file_with_md5(md5)
    Digest::MD5.stubs(:file).returns(stub(:hexdigest => md5))
  end

  describe '#prepare' do
    before :each do
      release.stubs(:tmpfile).returns(mock_file)
      release.stubs(:tmpdir).returns(mock_dir)
    end

    it 'should call sub methods with correct params' do
      release.expects(:download).with('/v3/files/puppetlabs-stdlib-4.1.0.tar.gz', mock_file)
      release.expects(:validate_checksum).with(mock_file, 'bbf919d7ee9d278d2facf39c25578bf8')
      release.expects(:unpack).with(mock_file, mock_dir)

      release.prepare
    end
  end

  describe '#tmpfile' do

    # This is impossible to test under Ruby 1.8.x, but should also occur there.
    it 'should be opened in binary mode', :unless => RUBY_VERSION >= '1.8.7' do
      Puppet::Forge::Cache.stubs(:base_path).returns(Dir.tmpdir)
      release.send(:tmpfile).binmode?.should be_true
    end
  end

  describe '#download' do
    it 'should call make_http_request with correct params' do
      # valid URI comes from file_uri in JSON blob above
      ssl_repository.expects(:make_http_request).with('/v3/files/puppetlabs-stdlib-4.1.0.tar.gz', mock_file).returns(mock_file)

      release.send(:download, '/v3/files/puppetlabs-stdlib-4.1.0.tar.gz', mock_file)
    end
  end

  describe '#verify_checksum' do
    it 'passes md5 check when valid' do
      # valid hash comes from file_md5 in JSON blob above
      mock_digest_file_with_md5('bbf919d7ee9d278d2facf39c25578bf8')

      release.send(:validate_checksum, mock_file, 'bbf919d7ee9d278d2facf39c25578bf8')
    end

    it 'fails md5 check when invalid' do
      mock_digest_file_with_md5('ffffffffffffffffffffffffffffffff')

      expect { release.send(:validate_checksum, mock_file, 'bbf919d7ee9d278d2facf39c25578bf8') }.to raise_error(RuntimeError, /did not match expected checksum/)
    end
  end

  describe '#unpack' do
    it 'should call unpacker with correct params' do
      Puppet::ModuleTool::Applications::Unpacker.expects(:unpack).with(mock_file.path, mock_dir).returns(true)

      release.send(:unpack, mock_file, mock_dir)
    end
  end
end
