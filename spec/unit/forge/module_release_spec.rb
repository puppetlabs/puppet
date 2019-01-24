# encoding: utf-8
require 'spec_helper'
require 'puppet/forge'
require 'net/http'
require 'puppet/module_tool'

describe Puppet::Forge::ModuleRelease do
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
  let(:uri) { " "}
  let(:release) { Puppet::Forge::ModuleRelease.new(ssl_repository, JSON.parse(release_json)) }

  let(:mock_file) {
    mock_io = StringIO.new
    allow(mock_io).to receive(:path).and_return('/dev/null')
    mock_io
  }

  let(:mock_dir) { '/tmp' }

  shared_examples 'a module release' do
    def mock_digest_file_with_md5(md5)
      allow(Digest::MD5).to receive(:file).and_return(double(:hexdigest => md5))
    end

    describe '#prepare' do
      before :each do
        allow(release).to receive(:tmpfile).and_return(mock_file)
        allow(release).to receive(:tmpdir).and_return(mock_dir)
      end

      it 'should call sub methods with correct params' do
        expect(release).to receive(:download).with("/#{api_version}/files/#{module_full_name_versioned}.tar.gz", mock_file)
        expect(release).to receive(:validate_checksum).with(mock_file, module_md5)
        expect(release).to receive(:unpack).with(mock_file, mock_dir)

        release.prepare
      end
    end

    describe '#tmpfile' do
      it 'should be opened in binary mode' do
        allow(Puppet::Forge::Cache).to receive(:base_path).and_return(Dir.tmpdir)
        expect(release.send(:tmpfile).binmode?).to be_truthy
      end
    end

    describe '#download' do
      it 'should call make_http_request with correct params' do
        # valid URI comes from file_uri in JSON blob above
        expect(ssl_repository).to receive(:make_http_request).with("/#{api_version}/files/#{module_full_name_versioned}.tar.gz", mock_file).and_return(double(:body => '{}', :code => '200'))

        release.send(:download, "/#{api_version}/files/#{module_full_name_versioned}.tar.gz", mock_file)
      end

      it 'should raise a response error when it receives an error from forge' do
        allow(ssl_repository).to receive(:make_http_request).and_return(double(:body => '{"errors": ["error"]}', :code => '500', :message => 'server error'))
        expect { release.send(:download, "/some/path", mock_file)}.to raise_error Puppet::Forge::Errors::ResponseError
      end
    end

    describe '#verify_checksum' do
      it 'passes md5 check when valid' do
        # valid hash comes from file_md5 in JSON blob above
        mock_digest_file_with_md5(module_md5)

        release.send(:validate_checksum, mock_file, module_md5)
      end

      it 'fails md5 check when invalid' do
        mock_digest_file_with_md5('ffffffffffffffffffffffffffffffff')

        expect { release.send(:validate_checksum, mock_file, module_md5) }.to raise_error(RuntimeError, /did not match expected checksum/)
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
        "source": "git://github.com/puppetlabs/puppetlabs-stdlib.git",
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
        "source": "git://github.com/puppetlabs/puppetlabs-stdlib.git",
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
      "file_md5": "#{module_md5}"
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
        "source": "git://github.com/puppetlabs/puppetlabs-stdlib.git",
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
