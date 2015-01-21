#! /usr/bin/env ruby
require 'spec_helper'
require 'uri'

source = Puppet::Type.type(:file).attrclass(:source)
describe Puppet::Type.type(:file).attrclass(:source) do
  include PuppetSpec::Files

  around :each do |example|
    Puppet.override(:environments => Puppet::Environments::Static.new) do
      example.run
    end
  end

  before do
    # Wow that's a messy interface to the resource.
    @environment = Puppet::Node::Environment.remote("myenv")
    @resource = stub 'resource', :[]= => nil, :property => nil, :catalog => Puppet::Resource::Catalog.new(nil, @environment), :line => 0, :file => ''
    @foobar = make_absolute("/foo/bar baz")
    @feebooz = make_absolute("/fee/booz baz")

    @foobar_uri  = URI.unescape(Puppet::Util.path_to_uri(@foobar).to_s)
    @feebooz_uri = URI.unescape(Puppet::Util.path_to_uri(@feebooz).to_s)
  end

  it "should be a subclass of Parameter" do
    expect(source.superclass).to eq(Puppet::Parameter)
  end

  describe "#validate" do
    let(:path) { tmpfile('file_source_validate') }
    let(:resource) { Puppet::Type.type(:file).new(:path => path) }

    it "should fail if the set values are not URLs" do
      URI.expects(:parse).with('foo').raises RuntimeError

      expect(lambda { resource[:source] = %w{foo} }).to raise_error(Puppet::Error)
    end

    it "should fail if the URI is not a local file, file URI, or puppet URI" do
      expect(lambda { resource[:source] = %w{http://foo/bar} }).to raise_error(Puppet::Error, /Cannot use URLs of type 'http' as source for fileserving/)
    end

    it "should strip trailing forward slashes", :unless => Puppet.features.microsoft_windows? do
      resource[:source] = "/foo/bar\\//"
      expect(resource[:source]).to eq(%w{file:/foo/bar\\})
    end

    it "should strip trailing forward and backslashes", :if => Puppet.features.microsoft_windows? do
      resource[:source] = "X:/foo/bar\\//"
      expect(resource[:source]).to eq(%w{file:/X:/foo/bar})
    end

    it "should accept an array of sources" do
      resource[:source] = %w{file:///foo/bar puppet://host:8140/foo/bar}
      expect(resource[:source]).to eq(%w{file:///foo/bar puppet://host:8140/foo/bar})
    end

    it "should accept file path characters that are not valid in URI" do
      resource[:source] = 'file:///foo bar'
    end

    it "should reject relative URI sources" do
      expect(lambda { resource[:source] = 'foo/bar' }).to raise_error(Puppet::Error)
    end

    it "should reject opaque sources" do
      expect(lambda { resource[:source] = 'mailto:foo@com' }).to raise_error(Puppet::Error)
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
    let(:path) { tmpfile('file_source_munge') }
    let(:resource) { Puppet::Type.type(:file).new(:path => path) }

    it "should prefix file scheme to absolute paths" do
      resource[:source] = path
      expect(resource[:source]).to eq([URI.unescape(Puppet::Util.path_to_uri(path).to_s)])
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
      @metadata = stub 'metadata', :source= => nil
      @resource.stubs(:[]).with(:links).returns :manage
      @resource.stubs(:[]).with(:source_permissions).returns :use
      @resource.stubs(:[]).with(:checksum).returns :checksum
    end

    it "should return already-available metadata" do
      @source = source.new(:resource => @resource)
      @source.metadata = "foo"
      expect(@source.metadata).to eq("foo")
    end

    it "should return nil if no @should value is set and no metadata is available" do
      @source = source.new(:resource => @resource)
      expect(@source.metadata).to be_nil
    end

    it "should collect its metadata using the Metadata class if it is not already set" do
      @source = source.new(:resource => @resource, :value => @foobar)
      Puppet::FileServing::Metadata.indirection.expects(:find).with do |uri, options|
        expect(uri).to eq @foobar_uri
        expect(options[:environment]).to eq @environment
        expect(options[:links]).to eq :manage
        expect(options[:checksum_type]).to eq :checksum
      end.returns @metadata

      @source.metadata
    end

    it "should use the metadata from the first found source" do
      metadata = stub 'metadata', :source= => nil
      @source = source.new(:resource => @resource, :value => [@foobar, @feebooz])
      options = {
        :environment => @environment,
        :links => :manage,
        :source_permissions => :use,
        :checksum_type => :checksum
      }
      Puppet::FileServing::Metadata.indirection.expects(:find).with(@foobar_uri, options).returns nil
      Puppet::FileServing::Metadata.indirection.expects(:find).with(@feebooz_uri, options).returns metadata
      expect(@source.metadata).to equal(metadata)
    end

    it "should store the found source as the metadata's source" do
      metadata = mock 'metadata'
      @source = source.new(:resource => @resource, :value => @foobar)
      Puppet::FileServing::Metadata.indirection.expects(:find).with do |uri, options|
        expect(uri).to eq @foobar_uri
        expect(options[:environment]).to eq @environment
        expect(options[:links]).to eq :manage
        expect(options[:checksum_type]).to eq :checksum
      end.returns metadata

      metadata.expects(:source=).with(@foobar_uri)
      @source.metadata
    end

    it "should fail intelligently if an exception is encountered while querying for metadata" do
      @source = source.new(:resource => @resource, :value => @foobar)
      Puppet::FileServing::Metadata.indirection.expects(:find).with do |uri, options|
        expect(uri).to eq @foobar_uri
        expect(options[:environment]).to eq @environment
        expect(options[:links]).to eq :manage
        expect(options[:checksum_type]).to eq :checksum
      end.raises RuntimeError

      @source.expects(:fail).raises ArgumentError
      expect { @source.metadata }.to raise_error(ArgumentError)
    end

    it "should fail if no specified sources can be found" do
      @source = source.new(:resource => @resource, :value => @foobar)
      Puppet::FileServing::Metadata.indirection.expects(:find).with  do |uri, options|
        expect(uri).to eq @foobar_uri
        expect(options[:environment]).to eq @environment
        expect(options[:links]).to eq :manage
        expect(options[:checksum_type]).to eq :checksum
      end.returns nil

      @source.expects(:fail).raises RuntimeError

      expect { @source.metadata }.to raise_error(RuntimeError)
    end
  end

  it "should have a method for setting the desired values on the resource" do
    expect(source.new(:resource => @resource)).to respond_to(:copy_source_values)
  end

  describe "when copying the source values" do
    before :each do
      @resource = Puppet::Type.type(:file).new :path => @foobar

      @source = source.new(:resource => @resource)
      @metadata = stub 'metadata', :owner => 100, :group => 200, :mode => "173", :checksum => "{md5}asdfasdf", :ftype => "file", :source => @foobar
      @source.stubs(:metadata).returns @metadata

      Puppet.features.stubs(:root?).returns true
    end

    it "should not issue an error - except on Windows - if the source mode value is a Numeric" do
      @metadata.stubs(:mode).returns 0173
      @resource[:source_permissions] = :use
      if Puppet::Util::Platform.windows?
        expect { @source.copy_source_values }.to raise_error("Copying owner/mode/group from the source file on Windows is not supported; use source_permissions => ignore.")
      else
        expect { @source.copy_source_values }.not_to raise_error
      end
    end

    it "should not issue an error - except on Windows - if the source mode value is a String" do
      @metadata.stubs(:mode).returns "173"
      @resource[:source_permissions] = :use
      if Puppet::Util::Platform.windows?
        expect { @source.copy_source_values }.to raise_error("Copying owner/mode/group from the source file on Windows is not supported; use source_permissions => ignore.")
      else
        expect { @source.copy_source_values }.not_to raise_error
      end
    end

    it "should fail if there is no metadata" do
      @source.stubs(:metadata).returns nil
      @source.expects(:devfail).raises ArgumentError
      expect { @source.copy_source_values }.to raise_error(ArgumentError)
    end

    it "should set :ensure to the file type" do
      @metadata.stubs(:ftype).returns "file"

      @source.copy_source_values
      expect(@resource[:ensure]).to eq(:file)
    end

    it "should not set 'ensure' if it is already set to 'absent'" do
      @metadata.stubs(:ftype).returns "file"

      @resource[:ensure] = :absent
      @source.copy_source_values
      expect(@resource[:ensure]).to eq(:absent)
    end

    describe "and the source is a file" do
      before do
        @metadata.stubs(:ftype).returns "file"
        Puppet.features.stubs(:microsoft_windows?).returns false
      end

      context "when source_permissions is `use`" do
        before :each do
          @resource[:source_permissions] = "use"
        end

        it "should copy the metadata's owner, group, checksum, and mode to the resource if they are not set on the resource" do
          @source.copy_source_values

          expect(@resource[:owner]).to eq(100)
          expect(@resource[:group]).to eq(200)
          expect(@resource[:mode]).to eq("173")

          # Metadata calls it checksum, we call it content.
          expect(@resource[:content]).to eq(@metadata.checksum)
        end

        it "should not copy the metadata's owner, group, checksum and mode to the resource if they are already set" do
          @resource[:owner] = 1
          @resource[:group] = 2
          @resource[:mode] = '173'
          @resource[:content] = "foobar"

          @source.copy_source_values

          expect(@resource[:owner]).to eq(1)
          expect(@resource[:group]).to eq(2)
          expect(@resource[:mode]).to eq('173')
          expect(@resource[:content]).not_to eq(@metadata.checksum)
        end

        describe "and puppet is not running as root" do
          before do
            Puppet.features.stubs(:root?).returns false
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
          Puppet.features.expects(:root?).returns true
          @source.stubs(:local?).returns(false)
        end

        context "when managing a new file" do
          it "should copy owner and group from local sources" do
            @source.stubs(:local?).returns true

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
            Puppet::FileSystem.stubs(:exist?).with(@resource[:path]).returns(true)
          end

          it "should not copy owner, group or mode from local sources" do
            @source.stubs(:local?).returns true

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
          @source.stubs(:local?).returns(false)
          Puppet.features.expects(:root?).returns true
        end

        it "should not copy owner, group or mode from local sources" do
          @source.stubs(:local?).returns true

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

      describe "on Windows when source_permissions is `use`" do
        before :each do
          Puppet.features.stubs(:microsoft_windows?).returns true
          @resource[:source_permissions] = "use"
        end
        let(:err_message) { "Copying owner/mode/group from the" <<
              " source file on Windows is not supported;" <<
              " use source_permissions => ignore." }

        it "should issue error when copying from remote sources" do
          @source.stubs(:local?).returns false

          expect { @source.copy_source_values }.to raise_error(err_message)
        end

        it "should issue error when copying from local sources" do
          @source.stubs(:local?).returns true

          expect { @source.copy_source_values }.to raise_error(err_message)
        end

        it "should issue error when copying metadata from remote sources if only user is unspecified" do
          @source.stubs(:local?).returns false
          @resource[:group] = 2
          @resource[:mode] = "0003"

          expect { @source.copy_source_values }.to raise_error(err_message)
        end

        it "should issue error when copying metadata from remote sources if only group is unspecified" do
          @source.stubs(:local?).returns false
          @resource[:owner] = 1
          @resource[:mode] = "0003"

          expect { @source.copy_source_values }.to raise_error(err_message)
        end

        it "should issue error when copying metadata from remote sources if only mode is unspecified" do
          @source.stubs(:local?).returns false
          @resource[:owner] = 1
          @resource[:group] = 2

          expect { @source.copy_source_values }.to raise_error(err_message)
        end

        it "should not issue error when copying metadata from remote sources if group, owner, and mode are all specified" do
          @source.stubs(:local?).returns false
          @resource[:owner] = 1
          @resource[:group] = 2
          @resource[:mode] = "0003"

          expect { @source.copy_source_values }.not_to raise_error
        end
      end
    end

    describe "and the source is a link" do
      it "should set the target to the link destination" do
        @metadata.stubs(:ftype).returns "link"
        @metadata.stubs(:links).returns "manage"
        @resource.stubs(:[])
        @resource.stubs(:[]=)

        @metadata.expects(:destination).returns "/path/to/symlink"

        @resource.expects(:[]=).with(:target, "/path/to/symlink")
        @source.copy_source_values
      end
    end
  end

  it "should have a local? method" do
    expect(source.new(:resource => @resource)).to be_respond_to(:local?)
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

      describe "on Windows systems", :if => Puppet.features.microsoft_windows? do
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

    describe "for remote sources" do
      let(:sourcepath) { "/path/to/source" }
      let(:uri) { URI::Generic.build(:scheme => 'puppet', :host => 'server', :port => 8192, :path => sourcepath).to_s }

      before(:each) do
        metadata = Puppet::FileServing::Metadata.new(path, :source => uri, 'type' => 'file')
        #metadata = stub('remote', :ftype => "file", :source => uri)
        Puppet::FileServing::Metadata.indirection.stubs(:find).
          with(uri,all_of(has_key(:environment), has_key(:links))).returns metadata
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
