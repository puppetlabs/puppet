#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

source = Puppet::Type.type(:file).attrclass(:source)
describe Puppet::Type.type(:file).attrclass(:source) do
    before do
        # Wow that's a messy interface to the resource.
        @resource = stub 'resource', :uri2obj => true, :[]= => nil, :property => nil
    end

    it "should be a subclass of Property" do
        source.superclass.must == Puppet::Property
    end

    describe "when initializing" do
        it "should fail if the 'should' values are not URLs" do
            @resource.expects(:uri2obj).with("foo").returns false

            lambda { source.new(:resource => @resource, :should => %w{foo}) }.must raise_error(Puppet::Error)
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
            @source = source.new(:resource => @resource, :should => "/foo/bar")
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").returns @metadata
            @source.metadata
        end

        it "should use the metadata from the first found source" do
            metadata = stub 'metadata', :source= => nil
            @source = source.new(:resource => @resource, :should => ["/foo/bar", "/fee/booz"])
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").returns nil
            Puppet::FileServing::Metadata.expects(:find).with("/fee/booz").returns metadata
            @source.metadata.should equal(metadata)
        end

        it "should store the found source as the metadata's source" do
            metadata = mock 'metadata'
            @source = source.new(:resource => @resource, :should => "/foo/bar")
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").returns metadata

            metadata.expects(:source=).with("/foo/bar")
            @source.metadata
        end

        it "should fail intelligently if an exception is encountered while querying for metadata" do
            @source = source.new(:resource => @resource, :should => "/foo/bar")
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").raises RuntimeError

            @source.expects(:fail).raises ArgumentError
            lambda { @source.metadata }.should raise_error(ArgumentError)
        end

        it "should fail if no specified sources can be found" do
            @source = source.new(:resource => @resource, :should => "/foo/bar")
            Puppet::FileServing::Metadata.expects(:find).with("/foo/bar").returns nil

            @source.expects(:fail).raises RuntimeError

            lambda { @source.metadata }.should raise_error(RuntimeError)
        end
    end

    it "should have a method for setting the desired values on the resource" do
        source.new(:resource => @resource).must respond_to(:copy_source_values)
    end

    describe "when copying the source values" do
        before do
            @metadata = stub 'metadata', :owner => 100, :group => 200, :mode => 123

            @source = source.new(:resource => @resource)
            @source.metadata = @metadata

            @resource.stubs(:deleting?).returns false
        end

        it "should fail if there is no metadata" do
            @source.metadata = nil
            @source.expects(:devfail).raises ArgumentError
            lambda { @source.copy_source_values }.should raise_error(ArgumentError)
        end

        it "should set :ensure to the file type if the resource is not being deleted" do
            @resource.expects(:deleting?).returns false
            @resource.stubs(:[])
            @resource.stubs(:[]=)
            @metadata.stubs(:ftype).returns "foobar"

            @resource.expects(:[]=).with(:ensure, "foobar")
            @source.copy_source_values
        end

        it "should not set :ensure to the file type if the resource is being deleted" do
            @resource.expects(:deleting?).returns true
            @resource.stubs(:[])
            @resource.stubs(:[]).returns "foo"
            @metadata.expects(:ftype).returns "foobar"

            @resource.expects(:[]=).with(:ensure, "foobar").never
            @source.copy_source_values
        end

        describe "and the source is a file" do
            before do
                @metadata.stubs(:ftype).returns "file"
            end

            it "should copy the metadata's owner, group, and mode to the resource if they are not set on the resource" do
                @resource.stubs(:[]).returns nil

                @resource.expects(:[]=).with(:owner, 100)
                @resource.expects(:[]=).with(:group, 200)
                @resource.expects(:[]=).with(:mode, 123)

                @source.copy_source_values
            end

            it "should not copy the metadata's owner to the resource if it is already set" do
                @resource.stubs(:[]).returns "value"
                @resource.expects(:[]).returns "value"

                @resource.expects(:[]=).never

                @source.copy_source_values
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

    describe "when retrieving the property state" do
        it "should copy all metadata to the resource" do
            @source = source.new(:resource => @resource)
            @source.expects(:copy_source_values)

            @source.retrieve
        end
    end

    describe "when flushing" do
        it "should set its metadata to nil" do
            @source = source.new(:resource => @resource)
            @source.metadata = "foo"
            @source.flush
            @source.instance_variable_get("@metadata").should be_nil
        end

        it "should reset its content" do
            @source = source.new(:resource => @resource)
            @source.instance_variable_set("@content", "foo")
            @source.flush
            @source.instance_variable_get("@content").should be_nil
        end
    end

    it "should have a method for returning the content" do
        source.new(:resource => @resource).must respond_to(:content)
    end

    describe "when looking up the content" do
        before do
            @source = source.new(:resource => @resource)
            @metadata = stub 'metadata', :source => "/my/source"
            @source.metadata = @metadata

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
    end

    describe "when changing the content" do
        before do
            @source = source.new(:resource => @resource)
            @source.stubs(:content).returns "foobar"

            @metadata = stub 'metadata', :checksum => 123
            @source.metadata = @metadata
            @resource.stubs(:[]).with(:path).returns "/boo"
        end

        it "should use the file's :write method to write the content" do
            @resource.expects(:write).with("foobar", :source, 123)

            @source.sync
        end

        it "should return :file_changed if the file already existed" do
            @resource.stubs(:write)
            FileTest.expects(:exist?).with("/boo").returns true
            @source.sync.should == :file_changed
        end

        it "should return :file_created if the file already existed" do
            @resource.stubs(:write)
            FileTest.expects(:exist?).with("/boo").returns false
            @source.sync.should == :file_created
        end
    end
end
