# encoding: utf-8
require 'spec_helper'
require 'puppet/forge'
require 'net/http'
require 'puppet/module_tool'
require 'puppet_spec/files'

describe Puppet::Forge::ModuleRelease do
  include PuppetSpec::Files

  let(:agent) { "Test/1.0" }
  let(:repository) { Puppet::Forge::Repository.new('http://fake.com', agent) }
  let(:ssl_repository) { Puppet::Forge::Repository.new('https://fake.com', agent) }
  let(:api_version) { "v3" }
  let(:module_author) { "puppetlabs" }
  let(:module_name) { "stdlib" }
  let(:module_version) { "4.1.0" }
  let(:module_full_name) { "#{module_author}-#{module_name}" }
  let(:module_full_name_versioned) { "#{module_full_name}-#{module_version}" }
  let(:module_md5) { "bbf919d7ee9d278d2facf39c25578bf8" }
  let(:module_sha256) { "b4c6f15cec64a9fe16ef0d291e2598fc84f381bc59f0e67198d61706fafedae4" }
  let(:uri) { " "}
  let(:release) { Puppet::Forge::ModuleRelease.new(ssl_repository, JSON.parse(release_json)) }

  let(:mock_file) { double('file', path: '/dev/null') }
  let(:mock_dir) { tmpdir('dir') }

  let(:destination) { tmpfile('forge_module_release') }

  shared_examples 'a module release' do
    def mock_digest_file_with_md5(md5)
      allow(Digest::MD5).to receive(:file).and_return(double(:hexdigest => md5))
    end

    describe '#tmpfile' do
      it 'should be opened in binary mode' do
        allow(Puppet::Forge::Cache).to receive(:base_path).and_return(Dir.tmpdir)
        expect(release.send(:tmpfile).binmode?).to be_truthy
      end
    end

    describe '#download' do
      it 'should download a file' do
        stub_request(:get, "https://fake.com/#{api_version}/files/#{module_full_name_versioned}.tar.gz").to_return(status: 200, body: '{}')

        File.open(destination, 'wb') do |fh|
          release.send(:download, "/#{api_version}/files/#{module_full_name_versioned}.tar.gz", fh)
        end

        expect(File.read(destination)).to eq("{}")
      end

      it 'should raise a response error when it receives an error from forge' do
        stub_request(:get, "https://fake.com/some/path").to_return(
          status: [500, 'server error'],
          body: '{"error":"invalid module"}'
        )
        expect {
          release.send(:download, "/some/path", StringIO.new)
        }.to raise_error Puppet::Forge::Errors::ResponseError
      end
    end

    describe '#unpack' do
      it 'should call unpacker with correct params' do
        expect(Puppet::ModuleTool::Applications::Unpacker).to receive(:unpack).with(mock_file.path, mock_dir).and_return(true)

        release.send(:unpack, mock_file, mock_dir)
      end
    end
  end

  context 'standard forge module' do
    let(:release_json) do %Q{
    {
      "uri": "/#{api_version}/releases/#{module_full_name_versioned}",
      "module": {
        "uri": "/#{api_version}/modules/#{module_full_name}",
        "name": "#{module_name}",
        "owner": {
          "uri": "/#{api_version}/users/#{module_author}",
          "username": "#{module_author}",
          "gravatar_id": "fdd009b7c1ec96e088b389f773e87aec"
        }
      },
      "version": "#{module_version}",
      "metadata": {
        "types": [ ],
        "license": "Apache 2.0",
        "checksums": { },
        "version": "#{module_version}",
        "description": "Standard Library for Puppet Modules",
        "source": "https://github.com/puppetlabs/puppetlabs-stdlib",
        "project_page": "https://github.com/puppetlabs/puppetlabs-stdlib",
        "summary": "Puppet Module Standard Library",
        "dependencies": [

        ],
        "author": "#{module_author}",
        "name": "#{module_full_name}"
      },
      "tags": [
        "puppetlabs",
        "library",
        "stdlib",
        "standard",
        "stages"
      ],
      "file_uri": "/#{api_version}/files/#{module_full_name_versioned}.tar.gz",
      "file_size": 67586,
      "file_md5": "#{module_md5}",
      "file_sha256": "#{module_sha256}",
      "downloads": 610751,
      "readme": "",
      "changelog": "",
      "license": "",
      "created_at": "2013-05-13 08:31:19 -0700",
      "updated_at": "2013-05-13 08:31:19 -0700",
      "deleted_at": null
    }
    }
    end

    it_behaves_like 'a module release'

    context 'when verifying checksums' do
      let(:json) { JSON.parse(release_json) }

      def mock_release(json)
        release = Puppet::Forge::ModuleRelease.new(ssl_repository, json)
        allow(release).to receive(:tmpfile).and_return(mock_file)
        allow(release).to receive(:tmpdir).and_return(mock_dir)
        allow(release).to receive(:download).with("/#{api_version}/files/#{module_full_name_versioned}.tar.gz", mock_file)
        allow(release).to receive(:unpack)
        release
      end

      it 'verifies using SHA256' do
        expect(Digest::SHA256).to receive(:file).and_return(double(:hexdigest => module_sha256))

        release = mock_release(json)
        release.prepare
      end

      it 'rejects an invalid release with SHA256' do
        expect(Digest::SHA256).to receive(:file).and_return(double(:hexdigest => 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'))

        release = mock_release(json)
        expect {
          release.prepare
        }.to raise_error(RuntimeError, /did not match expected checksum/)
      end

      context 'when `file_sha256` is missing' do
        before(:each) do
          json.delete('file_sha256')
        end

        it 'verifies using MD5 if `file_sha256` is missing' do
          expect(Digest::MD5).to receive(:file).and_return(double(:hexdigest => module_md5))

          release = mock_release(json)
          release.prepare
        end

        it 'rejects an invalid release with MD5' do
          expect(Digest::MD5).to receive(:file).and_return(double(:hexdigest => 'ffffffffffffffffffffffffffffffff'))

          release = mock_release(json)
          expect {
            release.prepare
          }.to raise_error(RuntimeError, /did not match expected checksum/)
        end

        it 'raises if FIPS is enabled' do
          allow(Facter).to receive(:value).with(:fips_enabled).and_return(true)

          release = mock_release(json)
          expect {
            release.prepare
          }.to raise_error(/Module install using MD5 is prohibited in FIPS mode./)
        end
      end
    end
  end

  context 'forge module with no dependencies field' do
    let(:release_json) do %Q{
    {
      "uri": "/#{api_version}/releases/#{module_full_name_versioned}",
      "module": {
        "uri": "/#{api_version}/modules/#{module_full_name}",
        "name": "#{module_name}",
        "owner": {
          "uri": "/#{api_version}/users/#{module_author}",
          "username": "#{module_author}",
          "gravatar_id": "fdd009b7c1ec96e088b389f773e87aec"
        }
      },
      "version": "#{module_version}",
      "metadata": {
        "types": [ ],
        "license": "Apache 2.0",
        "checksums": { },
        "version": "#{module_version}",
        "description": "Standard Library for Puppet Modules",
        "source": "https://github.com/puppetlabs/puppetlabs-stdlib",
        "project_page": "https://github.com/puppetlabs/puppetlabs-stdlib",
        "summary": "Puppet Module Standard Library",
        "author": "#{module_author}",
        "name": "#{module_full_name}"
      },
      "tags": [
        "puppetlabs",
        "library",
        "stdlib",
        "standard",
        "stages"
      ],
      "file_uri": "/#{api_version}/files/#{module_full_name_versioned}.tar.gz",
      "file_size": 67586,
      "file_md5": "#{module_md5}",
      "file_sha256": "#{module_sha256}",
      "downloads": 610751,
      "readme": "",
      "changelog": "",
      "license": "",
      "created_at": "2013-05-13 08:31:19 -0700",
      "updated_at": "2013-05-13 08:31:19 -0700",
      "deleted_at": null
    }
    }
    end

    it_behaves_like 'a module release'
  end

  context 'forge module with the minimal set of fields' do
    let(:release_json) do %Q{
    {
      "uri": "/#{api_version}/releases/#{module_full_name_versioned}",
      "module": {
        "uri": "/#{api_version}/modules/#{module_full_name}",
        "name": "#{module_name}"
      },
      "metadata": {
        "version": "#{module_version}",
        "name": "#{module_full_name}"
      },
      "file_uri": "/#{api_version}/files/#{module_full_name_versioned}.tar.gz",
      "file_size": 67586,
      "file_md5": "#{module_md5}",
      "file_sha256": "#{module_sha256}"
    }
    }
    end

    it_behaves_like 'a module release'
  end

  context 'deprecated forge module' do
    let(:release_json) do %Q{
    {
      "uri": "/#{api_version}/releases/#{module_full_name_versioned}",
      "module": {
        "uri": "/#{api_version}/modules/#{module_full_name}",
        "name": "#{module_name}",
        "deprecated_at": "2017-10-10 10:21:32 -0700",
        "owner": {
          "uri": "/#{api_version}/users/#{module_author}",
          "username": "#{module_author}",
          "gravatar_id": "fdd009b7c1ec96e088b389f773e87aec"
        }
      },
      "version": "#{module_version}",
      "metadata": {
        "types": [ ],
        "license": "Apache 2.0",
        "checksums": { },
        "version": "#{module_version}",
        "description": "Standard Library for Puppet Modules",
        "source": "https://github.com/puppetlabs/puppetlabs-stdlib",
        "project_page": "https://github.com/puppetlabs/puppetlabs-stdlib",
        "summary": "Puppet Module Standard Library",
        "dependencies": [

        ],
        "author": "#{module_author}",
        "name": "#{module_full_name}"
      },
      "tags": [
        "puppetlabs",
        "library",
        "stdlib",
        "standard",
        "stages"
      ],
      "file_uri": "/#{api_version}/files/#{module_full_name_versioned}.tar.gz",
      "file_size": 67586,
      "file_md5": "#{module_md5}",
      "file_sha256": "#{module_sha256}",
      "downloads": 610751,
      "readme": "",
      "changelog": "",
      "license": "",
      "created_at": "2013-05-13 08:31:19 -0700",
      "updated_at": "2013-05-13 08:31:19 -0700",
      "deleted_at": null
    }
    }
    end

    it_behaves_like 'a module release'

    describe '#prepare' do
      before :each do
        allow(release).to receive(:tmpfile).and_return(mock_file)
        allow(release).to receive(:tmpdir).and_return(mock_dir)
        allow(release).to receive(:download)
        allow(release).to receive(:validate_checksum)
        allow(release).to receive(:unpack)
      end

      it 'should emit warning about module deprecation' do
        expect(Puppet).to receive(:warning).with(/#{Regexp.escape(module_full_name)}.*deprecated/i)

        release.prepare
      end
    end
  end
end
