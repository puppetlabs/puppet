require 'spec_helper'
require 'uri'
require 'puppet/network/http_pool'
#require 'puppet/network/resolver'

describe Puppet::Type.type(:file).attrclass(:source), :uses_checksums => true do
  include PuppetSpec::Files
  include_context 'with supported checksum types'

  around :each do |example|
    Puppet.override(:environments => Puppet::Environments::Static.new) do
      example.run
    end
  end

  let(:filename) { tmpfile('file_source_validate') }
  let(:environment) { Puppet::Node::Environment.remote("myenv") }
  let(:catalog) { Puppet::Resource::Catalog.new(:test, environment) }
  let(:resource) { Puppet::Type.type(:file).new :path => filename, :catalog => catalog }

  before do
    @foobar = make_absolute("/foo/bar baz")
    @feebooz = make_absolute("/fee/booz baz")

    @foobar_uri  = URI.unescape(Puppet::Util.path_to_uri(@foobar).to_s)
    @feebooz_uri = URI.unescape(Puppet::Util.path_to_uri(@feebooz).to_s)
  end

  it "should be a subclass of Parameter" do
    expect(described_class.superclass).to eq(Puppet::Parameter)
  end

  describe "#validate" do
    it "should fail if the set values are not URLs" do
      expect(URI).to receive(:parse).with('foo').and_raise(RuntimeError)

      expect { resource[:source] = %w{foo} }.to raise_error(Puppet::Error)
    end

    it "should fail if the URI is not a local file, file URI, or puppet URI" do
      expect { resource[:source] = %w{ftp://foo/bar} }.to raise_error(Puppet::Error, /Cannot use URLs of type 'ftp' as source for fileserving/)
    end

    it "should strip trailing forward slashes", :unless => Puppet::Util::Platform.windows? do
      resource[:source] = "/foo/bar\\//"
      expect(resource[:source].first).to match(%r{/foo/bar\\$})
    end

    it "should strip trailing forward and backslashes", :if => Puppet::Util::Platform.windows? do
      resource[:source] = "X:/foo/bar\\//"
      expect(resource[:source].first).to match(/(file\:|file\:\/\/)\/X:\/foo\/bar$/)
    end

    it "should accept an array of sources" do
      resource[:source] = %w{file:///foo/bar puppet://host:8140/foo/bar}
      expect(resource[:source]).to eq(%w{file:///foo/bar puppet://host:8140/foo/bar})
    end

    it "should accept file path characters that are not valid in URI" do
      resource[:source] = 'file:///foo bar'
    end

    it "should reject relative URI sources" do
      expect { resource[:source] = 'foo/bar' }.to raise_error(Puppet::Error)
    end

    it "should reject opaque sources" do
      expect { resource[:source] = 'mailto:foo@com' }.to raise_error(Puppet::Error)
    end

    it "should accept URI authority component" do
      resource[:source] = 'file://host/foo'
      expect(resource[:source]).to eq(%w{file://host/foo})
    end

    it "should accept when URI authority is absent" do
      resource[:source] = 'file:///foo/bar'
      expect(resource[:source]).to eq(%w{file:///foo/bar})
    end
  end

  describe "#munge" do
    it "should prefix file scheme to absolute paths" do
      resource[:source] = filename
      expect(resource[:source]).to eq([URI.unescape(Puppet::Util.path_to_uri(filename).to_s)])
    end

    %w[file puppet].each do |scheme|
      it "should not prefix valid #{scheme} URIs" do
        resource[:source] = "#{scheme}:///foo bar"
        expect(resource[:source]).to eq(["#{scheme}:///foo bar"])
      end
    end
  end

  describe "when returning the metadata" do
    before do
      @metadata = double('metadata', :source= => nil)
      allow(resource).to receive(:[]).with(:links).and_return(:manage)
      allow(resource).to receive(:[]).with(:source_permissions).and_return(:use)
      allow(resource).to receive(:[]).with(:checksum).and_return(:checksum)
    end

    it "should return already-available metadata" do
      @source = described_class.new(:resource => resource)
      @source.metadata = "foo"
      expect(@source.metadata).to eq("foo")
    end

    it "should return nil if no @should value is set and no metadata is available" do
      @source = described_class.new(:resource => resource)
      expect(@source.metadata).to be_nil
    end

    it "should collect its metadata using the Metadata class if it is not already set" do
      @source = described_class.new(:resource => resource, :value => @foobar)
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find) do |uri, options|
        expect(uri).to eq(@foobar_uri)
        expect(options[:environment]).to eq(environment)
        expect(options[:links]).to eq(:manage)
        expect(options[:checksum_type]).to eq(:checksum)

        @metadata
      end

      @source.metadata
    end

    it "should use the metadata from the first found source" do
      metadata = double('metadata', :source= => nil)
      @source = described_class.new(:resource => resource, :value => [@foobar, @feebooz])
      options = {
        :environment => environment,
        :links => :manage,
        :source_permissions => :use,
        :checksum_type => :checksum
      }
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(@foobar_uri, options).and_return(nil)
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(@feebooz_uri, options).and_return(metadata)
      expect(@source.metadata).to equal(metadata)
    end

    it "should store the found source as the metadata's source" do
      metadata = double('metadata')
      @source = described_class.new(:resource => resource, :value => @foobar)
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find) do |uri, options|
        expect(uri).to eq(@foobar_uri)
        expect(options[:environment]).to eq(environment)
        expect(options[:links]).to eq(:manage)
        expect(options[:checksum_type]).to eq(:checksum)

        metadata
      end

      expect(metadata).to receive(:source=).with(@foobar_uri)
      @source.metadata
    end

    it "should fail intelligently if an exception is encountered while querying for metadata" do
      @source = described_class.new(:resource => resource, :value => @foobar)
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find) do |uri, options|
        expect(uri).to eq(@foobar_uri)
        expect(options[:environment]).to eq(environment)
        expect(options[:links]).to eq(:manage)
        expect(options[:checksum_type]).to eq(:checksum)
      end.and_raise(RuntimeError)

      expect(@source).to receive(:fail).and_raise(ArgumentError)
      expect { @source.metadata }.to raise_error(ArgumentError)
    end

    it "should fail if no specified sources can be found" do
      @source = described_class.new(:resource => resource, :value => @foobar)
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find)  do |uri, options|
        expect(uri).to eq(@foobar_uri)
        expect(options[:environment]).to eq(environment)
        expect(options[:links]).to eq(:manage)
        expect(options[:checksum_type]).to eq(:checksum)

        nil
      end

      expect(@source).to receive(:fail).and_raise(RuntimeError)

      expect { @source.metadata }.to raise_error(RuntimeError)
    end
  end

  it "should have a method for setting the desired values on the resource" do
    expect(described_class.new(:resource => resource)).to respond_to(:copy_source_values)
  end

  describe "when copying the source values" do
    before do
      allow_any_instance_of(Puppet::Type.type(:file)).to receive(:file).and_return('my/file.pp')
      allow_any_instance_of(Puppet::Type.type(:file)).to receive(:line).and_return(5)
    end

    before :each do
      @resource = Puppet::Type.type(:file).new :path => @foobar

      @source = described_class.new(:resource => @resource)
      @metadata = double('metadata', :owner => 100, :group => 200, :mode => "173", :checksum => "{md5}asdfasdf", :checksum_type => "md5", :ftype => "file", :source => @foobar)
      allow(@source).to receive(:metadata).and_return(@metadata)

      allow(Puppet.features).to receive(:root?).and_return(true)
    end

    it "should not issue an error - except on Windows - if the source mode value is a Numeric" do
      allow(@metadata).to receive(:mode).and_return(0173)
      @resource[:source_permissions] = :use
      if Puppet::Util::Platform.windows?
        expect { @source.copy_source_values }.to raise_error("Should not have tried to use source owner/mode/group on Windows (file: my/file.pp, line: 5)")
      else
        expect { @source.copy_source_values }.not_to raise_error
      end
    end

    it "should not issue an error - except on Windows - if the source mode value is a String" do
      allow(@metadata).to receive(:mode).and_return("173")
      @resource[:source_permissions] = :use
      if Puppet::Util::Platform.windows?
        expect { @source.copy_source_values }.to raise_error("Should not have tried to use source owner/mode/group on Windows (file: my/file.pp, line: 5)")
      else
        expect { @source.copy_source_values }.not_to raise_error
      end
    end

    it "should fail if there is no metadata" do
      allow(@source).to receive(:metadata).and_return(nil)
      expect(@source).to receive(:devfail).and_raise(ArgumentError)
      expect { @source.copy_source_values }.to raise_error(ArgumentError)
    end

    it "should set :ensure to the file type" do
      allow(@metadata).to receive(:ftype).and_return("file")

      @source.copy_source_values
      expect(@resource[:ensure]).to eq(:file)
    end

    it "should not set 'ensure' if it is already set to 'absent'" do
      allow(@metadata).to receive(:ftype).and_return("file")

      @resource[:ensure] = :absent
      @source.copy_source_values
      expect(@resource[:ensure]).to eq(:absent)
    end

    describe "and the source is a file" do
      before do
        allow(@metadata).to receive(:ftype).and_return("file")
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
      end

      context "when source_permissions is `use`" do
        before :each do
          @resource[:source_permissions] = "use"
          @resource[:checksum] = :sha256
        end

        it "should copy the metadata's owner, group, checksum, checksum_type, and mode to the resource if they are not set on the resource" do
          @source.copy_source_values

          expect(@resource[:owner]).to eq(100)
          expect(@resource[:group]).to eq(200)
          expect(@resource[:mode]).to eq("173")

          # Metadata calls it checksum and checksum_type, we call it content and checksum.
          expect(@resource[:content]).to eq(@metadata.checksum)
          expect(@resource[:checksum]).to eq(@metadata.checksum_type.to_sym)
        end

        it "should not copy the metadata's owner, group, checksum, checksum_type, and mode to the resource if they are already set" do
          @resource[:owner] = 1
          @resource[:group] = 2
          @resource[:mode] = '173'
          @resource[:content] = "foobar"

          @source.copy_source_values

          expect(@resource[:owner]).to eq(1)
          expect(@resource[:group]).to eq(2)
          expect(@resource[:mode]).to eq('173')
          expect(@resource[:content]).not_to eq(@metadata.checksum)
          expect(@resource[:checksum]).not_to eq(@metadata.checksum_type.to_sym)
        end

        describe "and puppet is not running as root" do
          before do
            allow(Puppet.features).to receive(:root?).and_return(false)
          end

          it "should not try to set the owner" do
            @source.copy_source_values
            expect(@resource[:owner]).to be_nil
          end

          it "should not try to set the group" do
            @source.copy_source_values
            expect(@resource[:group]).to be_nil
          end
        end
      end

      context "when source_permissions is `use_when_creating`" do
        before :each do
          @resource[:source_permissions] = "use_when_creating"
          expect(Puppet.features).to receive(:root?).and_return(true)
          allow(@source).to receive(:local?).and_return(false)
        end

        context "when managing a new file" do
          it "should copy owner and group from local sources" do
            allow(@source).to receive(:local?).and_return(true)

            @source.copy_source_values

            expect(@resource[:owner]).to eq(100)
            expect(@resource[:group]).to eq(200)
            expect(@resource[:mode]).to eq("173")
          end

          it "copies the remote owner" do
            @source.copy_source_values

            expect(@resource[:owner]).to eq(100)
          end

          it "copies the remote group" do
            @source.copy_source_values

            expect(@resource[:group]).to eq(200)
          end

          it "copies the remote mode" do
            @source.copy_source_values

            expect(@resource[:mode]).to eq("173")
          end
        end

        context "when managing an existing file" do
          before :each do
            allow(Puppet::FileSystem).to receive(:exist?).with(@resource[:path]).and_return(true)
          end

          it "should not copy owner, group or mode from local sources" do
            allow(@source).to receive(:local?).and_return(true)

            @source.copy_source_values

            expect(@resource[:owner]).to be_nil
            expect(@resource[:group]).to be_nil
            expect(@resource[:mode]).to be_nil
          end

          it "preserves the local owner" do
            @source.copy_source_values

            expect(@resource[:owner]).to be_nil
          end

          it "preserves the local group" do
            @source.copy_source_values

            expect(@resource[:group]).to be_nil
          end

          it "preserves the local mode" do
            @source.copy_source_values

            expect(@resource[:mode]).to be_nil
          end
        end
      end

      context "when source_permissions is default" do
        before :each do
          allow(@source).to receive(:local?).and_return(false)
          expect(Puppet.features).to receive(:root?).and_return(true)
        end

        it "should not copy owner, group or mode from local sources" do
          allow(@source).to receive(:local?).and_return(true)

          @source.copy_source_values

          expect(@resource[:owner]).to be_nil
          expect(@resource[:group]).to be_nil
          expect(@resource[:mode]).to be_nil
        end

        it "preserves the local owner" do
          @source.copy_source_values

          expect(@resource[:owner]).to be_nil
        end

        it "preserves the local group" do
          @source.copy_source_values

          expect(@resource[:group]).to be_nil
        end

        it "preserves the local mode" do
          @source.copy_source_values

          expect(@resource[:mode]).to be_nil
        end
      end
    end

    describe "and the source is a link" do
      before do
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
      end

      it "should set the target to the link destination" do
        allow(@metadata).to receive(:ftype).and_return("link")
        allow(@metadata).to receive(:links).and_return("manage")
        allow(@metadata).to receive(:checksum_type).and_return(nil)
        allow(@resource).to receive(:[])
        allow(@resource).to receive(:[]=)

        expect(@metadata).to receive(:destination).and_return("/path/to/symlink")

        expect(@resource).to receive(:[]=).with(:target, "/path/to/symlink")
        @source.copy_source_values
      end
    end
  end

  it "should have a local? method" do
    expect(described_class.new(:resource => resource)).to be_respond_to(:local?)
  end

  context "when accessing source properties" do
    let(:catalog) { Puppet::Resource::Catalog.new }
    let(:path) { tmpfile('file_resource') }
    let(:resource) { Puppet::Type.type(:file).new(:path => path, :catalog => catalog) }
    let(:sourcepath) { tmpfile('file_source') }

    describe "for local sources" do
      before :each do
        FileUtils.touch(sourcepath)
      end

      describe "on POSIX systems", :if => Puppet.features.posix? do
        ['', "file:", "file://"].each do |prefix|
          it "with prefix '#{prefix}' should be local" do
            resource[:source] = "#{prefix}#{sourcepath}"
            expect(resource.parameter(:source)).to be_local
          end

          it "should be able to return the metadata source full path" do
            resource[:source] = "#{prefix}#{sourcepath}"
            expect(resource.parameter(:source).full_path).to eq(sourcepath)
          end
        end
      end

      describe "on Windows systems", :if => Puppet::Util::Platform.windows? do
        ['', "file:/", "file:///"].each do |prefix|
          it "should be local with prefix '#{prefix}'" do
            resource[:source] = "#{prefix}#{sourcepath}"
            expect(resource.parameter(:source)).to be_local
          end

          it "should be able to return the metadata source full path" do
            resource[:source] = "#{prefix}#{sourcepath}"
            expect(resource.parameter(:source).full_path).to eq(sourcepath)
          end

          it "should convert backslashes to forward slashes" do
            resource[:source] = "#{prefix}#{sourcepath.gsub(/\\/, '/')}"
          end
        end

        it "should be UNC with two slashes"
      end
    end

    %w{puppet http}.each do |scheme|
      describe "for remote (#{scheme}) sources" do
        let(:sourcepath) { "/path/to/source" }
        let(:uri) { URI::Generic.build(:scheme => scheme, :host => 'server', :port => 8192, :path => sourcepath).to_s }

        before(:each) do
          metadata = Puppet::FileServing::Metadata.new(path, :source => uri, 'type' => 'file')
          allow(Puppet::FileServing::Metadata.indirection).to receive(:find).
            with(uri, include(:environment, :links)).and_return(metadata)
          allow(Puppet::FileServing::Metadata.indirection).to receive(:find).
            with(uri, include(:environment, :links)).and_return(metadata)
          resource[:source] = uri
        end

        it "should not be local" do
          expect(resource.parameter(:source)).not_to be_local
        end

        it "should be able to return the metadata source full path" do
          expect(resource.parameter(:source).full_path).to eq("/path/to/source")
        end

        it "should be able to return the source server" do
          expect(resource.parameter(:source).server).to eq("server")
        end

        it "should be able to return the source port" do
          expect(resource.parameter(:source).port).to eq(8192)
        end

        if scheme == 'puppet'
          describe "which don't specify server or port" do
            let(:uri) { "puppet:///path/to/source" }

            it "should return the default source server" do
              Puppet[:server] = "myserver"
              expect(resource.parameter(:source).server).to eq("myserver")
            end

            it "should return the default source port" do
              Puppet[:masterport] = 1234
              expect(resource.parameter(:source).port).to eq(1234)
            end
          end
        end
      end
    end
  end

  describe "when writing" do
    describe "as puppet apply" do
      let(:source_content) { "source file content\r\n"*10 }
      before do
        Puppet[:default_file_terminus] = "file_server"
        resource[:source] = file_containing('apply', source_content)
      end

      it "should copy content from the source to the file" do
        source = resource.parameter(:source)
        resource.write(source)

        expect(Puppet::FileSystem.binread(filename)).to eq(source_content)
      end

      with_digest_algorithms do
        it "should return the checksum computed" do
          File.open(filename, 'wb') do |file|
            source = resource.parameter(:source)
            resource[:checksum] = digest_algorithm
            expect(source.write(file)).to eq("{#{digest_algorithm}}#{digest(source_content)}")
          end
        end
      end
    end

    describe "from local source" do
      let(:source_content) { "source file content\r\n"*10 }
      before do
        resource[:backup] = false
        resource[:source] = file_containing('source', source_content)
      end

      it "should copy content from the source to the file" do
        source = resource.parameter(:source)
        resource.write(source)

        expect(Puppet::FileSystem.binread(filename)).to eq(source_content)
      end

      with_digest_algorithms do
        it "should return the checksum computed" do
          File.open(filename, 'wb') do |file|
            source = resource.parameter(:source)
            resource[:checksum] = digest_algorithm
            expect(source.write(file)).to eq("{#{digest_algorithm}}#{digest(source_content)}")
          end
        end
      end
    end

    describe 'from remote source' do
      let(:source_content) { "source file content\n"*10 }
      let(:source) {
        attr = resource.newattr(:source)
        attr.metadata = metadata
        attr
      }
      let(:metadata) {
        Puppet::FileServing::Metadata.new(
          '/modules/:module/foo',
          {
            'type' => 'file',
            'source' => 'puppet:///modules/:module/foo'
          }
        )
      }

      before do
        resource[:backup] = false
      end

      it 'should use an explicit fileserver if source starts with puppet://' do
        metadata.source = "puppet://somehostname:8140/modules/:module/foo"

        stub_request(:get, %r{https://somehostname:8140/puppet/v3/file_content/modules/:module/foo})
          .to_return(status: 200, body: metadata.to_json, headers: { 'Content-Type' => 'application/json' })

        resource.write(source)
      end

      it 'should use the default fileserver if source starts with puppet:///' do
        stub_request(:get, %r{https://#{Puppet[:server]}:8140/puppet/v3/file_content/modules/:module/foo})
          .to_return(status: 200, body: metadata.to_json, headers: { 'Content-Type' => 'application/json' })

        resource.write(source)
      end

      it 'should percent encode reserved characters' do
        metadata.source = 'puppet:///modules/:module/foo bar'

        stub_request(:get, %r{/puppet/v3/file_content/modules/:module/foo%20bar})
          .to_return(status: 200, body: metadata.to_json, headers: { 'Content-Type' => 'application/json' })

        resource.write(source)
      end

      it 'should request binary content' do
        stub_request(:get, %r{/puppet/v3/file_content/modules/:module/foo}) do |request|
          expect(request.headers).to include({'Accept' => 'application/octet-stream'})
        end.to_return(status: 200, body: '', headers: { 'Content-Type' => 'application/octet-stream' })

        resource.write(source)
      end

      it "should request file content from the catalog's environment" do
        Puppet[:environment] = 'doesntexist'

        stub_request(:get, %r{/puppet/v3/file_content})
          .with(query: hash_including("environment" => "myenv"))
          .to_return(status: 200, body: '', headers: { 'Content-Type' => 'application/octet-stream' })

        resource.write(source)
      end

      describe 'when handling file_content responses' do
        before do
          File.open(filename, 'w') {|f| f.write "initial file content"}
        end

        it 'should not write anything if source is not found' do
          stub_request(:get, %r{/puppet/v3/file_content/modules/:module/foo}).to_return(status: 404)

          expect { resource.write(source) }.to raise_error(Net::HTTPError, /Error 404 on SERVER:/)
          expect(File.read(filename)).to eq('initial file content')
        end

        it 'should raise an HTTP error in case of server error' do
          stub_request(:get, %r{/puppet/v3/file_content/modules/:module/foo}).to_return(status: 500)

          expect { resource.write(source) }.to raise_error(Net::HTTPError, /Error 500 on SERVER/)
        end

        context 'and the request was successful' do
          before do
            stub_request(:get, %r{/puppet/v3/file_content/modules/:module/foo}).to_return(status: 200, body: source_content)
          end

          it 'should write the contents to the file' do
            resource.write(source)
            expect(Puppet::FileSystem.binread(filename)).to eq(source_content)
          end

          with_digest_algorithms do
            it 'should return the checksum computed' do
              File.open(filename, 'w') do |file|
                resource[:checksum] = digest_algorithm
                expect(source.write(file)).to eq("{#{digest_algorithm}}#{digest(source_content)}")
              end
            end
          end
        end
      end
    end
  end
end
