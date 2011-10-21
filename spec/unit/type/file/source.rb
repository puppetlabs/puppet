#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

source = Puppet::Type.type(:file).attrclass(:source)
describe Puppet::Type.type(:file).attrclass(:source) do
    before do
        # Wow that's a messy interface to the resource.
        @resource = stub 'resource', :[]= => nil, :property => nil, :catalog => stub("catalog", :dependent_data_expired? => false), :line => 12, :file => 'foo.pp'
    end

    it "should be a subclass of Parameter" do
        source.superclass.must == Puppet::Parameter
    end

    describe "when initializing" do
        it "should fail if the set values are not URLs" do
            s = source.new(:resource => @resource)
            URI.expects(:parse).with('foo').raises RuntimeError

            lambda { s.value = %w{foo} }.must raise_error(Puppet::Error)
        end

        it "should fail if the URI is not a local file, file URI, or puppet URI" do
            s = source.new(:resource => @resource)

            lambda { s.value = %w{http://foo/bar} }.must raise_error(Puppet::Error)
        end
    end

    it "should have a method for retrieving its metadata" do
        source.new(:resource => @resource).must respond_to(:metadata)
    end

    it "should have a method for setting its metadata" do
        source.new(:resource => @resource).must respond_to(:metadata=)
    end

    describe "when returning the metadata" do
        before do
            @metadata = stub 'metadata', :source= => nil
        end

        it "should return already-available metadata" do
            @source = source.new(:resource => @resource)
            @source.metadata = "foo"
            @source.metadata.should == "foo"
        end

        it "should return nil if no @should value is set and no metadata is available" do
            @source = source.new(:resource => @resource)
            @source.metadata.should be_nil
        end

        it "should collect its metadata using the Metadata class if it is not already set" do
            @source = source.new(:resource => @resource, :value => "/foo/bar")
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").returns @metadata
            @source.metadata
        end

        it "should use the metadata from the first found source" do
            metadata = stub 'metadata', :source= => nil
            @source = source.new(:resource => @resource, :value => ["/foo/bar", "/fee/booz"])
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").returns nil
            Puppet::FileServing::Metadata.expects(:find).with("/fee/booz").returns metadata
            @source.metadata.should equal(metadata)
        end

        it "should store the found source as the metadata's source" do
            metadata = mock 'metadata'
            @source = source.new(:resource => @resource, :value => "/foo/bar")
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").returns metadata

            metadata.expects(:source=).with("/foo/bar")
            @source.metadata
        end

        it "should fail intelligently if an exception is encountered while querying for metadata" do
            @source = source.new(:resource => @resource, :value => "/foo/bar")
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").raises RuntimeError

            @source.expects(:fail).raises ArgumentError
            lambda { @source.metadata }.should raise_error(ArgumentError)
        end

        it "should fail if no specified sources can be found" do
            @source = source.new(:resource => @resource, :value => "/foo/bar")
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").returns nil

            @source.expects(:fail).raises RuntimeError

            lambda { @source.metadata }.should raise_error(RuntimeError)
        end

        it "should expire the metadata appropriately" do
            expirer = stub 'expired', :dependent_data_expired? => true

            metadata = stub 'metadata', :source= => nil
            Puppet::FileServing::Metadata.expects(:find).with("/fee/booz").returns metadata

            @source = source.new(:resource => @resource, :value => ["/fee/booz"])
            @source.metadata = "foo"

            @source.stubs(:expirer).returns expirer

            @source.metadata.should_not == "foo"
        end
    end

    it "should have a method for setting the desired values on the resource" do
        source.new(:resource => @resource).must respond_to(:copy_source_values)
    end

    describe "when copying the source values" do
        before do
            @metadata = stub 'metadata', :owner => 100, :group => 200, :mode => 123, :checksum => "{md5}asdfasdf"

            @source = source.new(:resource => @resource)
            @source.metadata = @metadata

            @resource.stubs(:deleting?).returns false
        end

        it "should fail if there is no metadata" do
            @source.metadata = nil
            @source.expects(:devfail).raises ArgumentError
            lambda { @source.copy_source_values }.should raise_error(ArgumentError)
        end

        it "should set :ensure to the file type" do
            @resource.stubs(:[])
            @resource.stubs(:[]=)
            @metadata.stubs(:ftype).returns "foobar"

            @resource.expects(:[]=).with(:ensure, "foobar")
            @source.copy_source_values
        end

        it "should not set 'ensure' if it is already set to 'absent'" do
            @resource.stubs(:[])
            @resource.stubs(:[]=)
            @metadata.stubs(:ftype).returns "foobar"

            @resource.expects(:[]).with(:ensure).returns :absent
            @resource.expects(:[]=).with(:ensure, "foobar").never
            @source.copy_source_values
        end

        describe "and the source is a file" do
            before do
                @metadata.stubs(:ftype).returns "file"
            end

            it "should copy the metadata's owner, group, and mode to the resource if they are not set on the resource" do
                @resource.stubs(:[]).returns nil

                Puppet::Util::SUIDManager.expects(:uid).returns 0

                @resource.expects(:[]=).with(:owner, 100)
                @resource.expects(:[]=).with(:group, 200)
                @resource.expects(:[]=).with(:mode, 123)
                @resource.expects(:[]=).with(:checksum, "{md5}asdfasdf")

                @source.copy_source_values
            end

            it "should copy the metadata's owner, group, and mode to the resource if they are set to :absent on the resource" do
                @resource.stubs(:[]).returns :absent

                Puppet::Util::SUIDManager.expects(:uid).returns 0

                @resource.expects(:[]=).with(:owner, 100)
                @resource.expects(:[]=).with(:group, 200)
                @resource.expects(:[]=).with(:mode, 123)
                @resource.expects(:[]=).with(:checksum, "{md5}asdfasdf")

                @source.copy_source_values
            end

            it "should not copy the metadata's owner to the resource if it is already set" do
                @resource.stubs(:[]).returns "value"
                @resource.expects(:[]).returns "value"

                @resource.expects(:[]=).never

                @source.copy_source_values
            end

            describe "and puppet is not running as root" do
                it "should not try to set the owner" do
                    @resource.stubs(:[]).returns nil
                    @resource.stubs(:[]=)

                    @resource.expects(:[]=).with(:owner, 100).never

                    Puppet::Util::SUIDManager.expects(:uid).returns 100

                    @source.copy_source_values
                end
            end
        end

        describe "and the source is a link" do
            it "should set the target to the link destination" do
                @metadata.stubs(:ftype).returns "link"
                @resource.stubs(:[])
                @resource.stubs(:[]=)

                @metadata.expects(:destination).returns "/path/to/symlink"

                @resource.expects(:[]=).with(:target, "/path/to/symlink")
                @source.copy_source_values
            end
        end
    end

    it "should have a method for returning the content" do
        source.new(:resource => @resource).must respond_to(:content)
    end

    describe "when looking up the content" do
        before do
            @source = source.new(:resource => @resource)
            @metadata = stub 'metadata', :source => "/my/source"
            @source.stubs(:metadata).returns @metadata

            @content = stub 'content', :content => "foobar"
        end

        it "should fail if the metadata does not have a source set" do
            @metadata.stubs(:source).returns nil
            lambda { @source.content }.should raise_error(Puppet::DevError)
        end

        it "should look the content up from the Content class using the metadata source if no content is set" do
            Puppet::FileServing::Content.expects(:find).with("/my/source").returns @content
            @source.content.should == "foobar"
        end

        it "should return previously found content" do
            Puppet::FileServing::Content.expects(:find).with("/my/source").returns @content
            @source.content.should == "foobar"
            @source.content.should == "foobar"
        end

        it "should fail if no content can be retrieved" do
            Puppet::FileServing::Content.expects(:find).with("/my/source").returns nil
            @source.expects(:fail).raises RuntimeError
            lambda { @source.content }.should raise_error(RuntimeError)
        end

        it "should expire the content appropriately" do
            expirer = stub 'expired', :dependent_data_expired? => true

            content2 = stub 'content', :content => "secondrun"
            Puppet::FileServing::Content.expects(:find).with("/my/source").times(2).returns(@content).then.returns(content2)
            @source.content.should == "foobar"

            @source.stubs(:expirer).returns expirer

            @source.content.should == "secondrun"
        end
    end
end
