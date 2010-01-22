#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/resource'

describe Puppet::Resource do
    [:catalog, :file, :line].each do |attr|
        it "should have an #{attr} attribute" do
            resource = Puppet::Resource.new("file", "/my/file")
            resource.should respond_to(attr)
            resource.should respond_to(attr.to_s + "=")
        end
    end

    describe "when initializing" do
        it "should require the type and title" do
            lambda { Puppet::Resource.new }.should raise_error(ArgumentError)
        end

        it "should create a resource reference with its type and title" do
            ref = Puppet::Resource::Reference.new("file", "/f")
            Puppet::Resource::Reference.expects(:new).with("file", "/f").returns ref
            Puppet::Resource.new("file", "/f")
        end

        it "should tag itself with its type" do
            Puppet::Resource.new("file", "/f").should be_tagged("file")
        end

        it "should tag itself with its title if the title is a valid tag" do
            Puppet::Resource.new("file", "bar").should be_tagged("bar")
        end

        it "should not tag itself with its title if the title is a not valid tag" do
            Puppet::Resource.new("file", "/bar").should_not be_tagged("/bar")
        end

        it "should allow setting of attributes" do
            Puppet::Resource.new("file", "/bar", :file => "/foo").file.should == "/foo"
            Puppet::Resource.new("file", "/bar", :exported => true).should be_exported
        end
    end

    it "should use the resource reference to determine its type" do
        ref = Puppet::Resource::Reference.new("file", "/f")
        Puppet::Resource::Reference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:type).returns "mytype"
        resource.type.should == "mytype"
    end

    it "should use its resource reference to determine its title" do
        ref = Puppet::Resource::Reference.new("file", "/f")
        Puppet::Resource::Reference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:title).returns "mytitle"
        resource.title.should == "mytitle"
    end

    it "should use its resource reference to determine whether it is builtin" do
        ref = Puppet::Resource::Reference.new("file", "/f")
        Puppet::Resource::Reference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:builtin_type?).returns "yep"
        resource.builtin_type?.should == "yep"
    end

    it "should call its builtin_type? method when 'builtin?' is called" do
        resource = Puppet::Resource.new("file", "/f")
        resource.expects(:builtin_type?).returns "foo"
        resource.builtin?.should == "foo"
    end

    it "should use its resource reference to produce its canonical reference string" do
        ref = Puppet::Resource::Reference.new("file", "/f")
        Puppet::Resource::Reference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:to_s).returns "Foo[bar]"
        resource.ref.should == "Foo[bar]"
    end

    it "should be taggable" do
        Puppet::Resource.ancestors.should be_include(Puppet::Util::Tagging)
    end

    it "should have an 'exported' attribute" do
        resource = Puppet::Resource.new("file", "/f")
        resource.exported = true
        resource.exported.should == true
        resource.should be_exported
    end

    it "should support an environment attribute"

    it "should convert its environment into an environment instance if one is provided"

    it "should support a namespace attribute"

    describe "when managing parameters" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
        end

        it "should be able to check whether parameters are valid when the resource models builtin resources"

        it "should be able to check whether parameters are valid when the resource models defined resources"

        it "should allow setting and retrieving of parameters" do
            @resource[:foo] = "bar"
            @resource[:foo].should == "bar"
        end

        it "should allow setting of parameters at initialization" do
            Puppet::Resource.new("file", "/my/file", :parameters => {:foo => "bar"})[:foo].should == "bar"
        end

        it "should canonicalize retrieved parameter names to treat symbols and strings equivalently" do
            @resource[:foo] = "bar"
            @resource["foo"].should == "bar"
        end

        it "should canonicalize set parameter names to treat symbols and strings equivalently" do
            @resource["foo"] = "bar"
            @resource[:foo].should == "bar"
        end

        it "should set the namevar when asked to set the name" do
            Puppet::Type.type(:file).stubs(:namevar).returns :myvar
            @resource[:name] = "/foo"
            @resource[:myvar].should == "/foo"
        end

        it "should return the namevar when asked to return the name" do
            Puppet::Type.type(:file).stubs(:namevar).returns :myvar
            @resource[:myvar] = "/foo"
            @resource[:name].should == "/foo"
        end

        it "should be able to set the name for non-builtin types" do
            resource = Puppet::Resource.new(:foo, "bar")
            lambda { resource[:name] = "eh" }.should_not raise_error
        end

        it "should be able to return the name for non-builtin types" do
            resource = Puppet::Resource.new(:foo, "bar")
            resource[:name] = "eh"
            resource[:name].should == "eh"
        end

        it "should be able to iterate over parameters" do
            @resource[:foo] = "bar"
            @resource[:fee] = "bare"
            params = {}
            @resource.each do |key, value|
                params[key] = value
            end
            params.should == {:foo => "bar", :fee => "bare"}
        end

        it "should include Enumerable" do
            @resource.class.ancestors.should be_include(Enumerable)
        end

        it "should have a method for testing whether a parameter is included" do
            @resource[:foo] = "bar"
            @resource.should be_has_key(:foo)
            @resource.should_not be_has_key(:eh)
        end

        it "should have a method for providing the list of parameters" do
            @resource[:foo] = "bar"
            @resource[:bar] = "foo"
            keys = @resource.keys
            keys.should be_include(:foo)
            keys.should be_include(:bar)
        end

        it "should have a method for providing the number of parameters" do
            @resource[:foo] = "bar"
            @resource.length.should == 1
        end

        it "should have a method for deleting parameters" do
            @resource[:foo] = "bar"
            @resource.delete(:foo)
            @resource[:foo].should be_nil
        end

        it "should have a method for testing whether the parameter list is empty" do
            @resource.should be_empty
            @resource[:foo] = "bar"
            @resource.should_not be_empty
        end

        it "should be able to produce a hash of all existing parameters" do
            @resource[:foo] = "bar"
            @resource[:fee] = "yay"

            hash = @resource.to_hash
            hash[:foo].should == "bar"
            hash[:fee].should == "yay"
        end

        it "should not provide direct access to the internal parameters hash when producing a hash" do
            hash = @resource.to_hash
            hash[:foo] = "bar"
            @resource[:foo].should be_nil
        end

        it "should use the title as the namevar to the hash if no namevar is present" do
            Puppet::Type.type(:file).stubs(:namevar).returns :myvar
            @resource.to_hash[:myvar].should == "/my/file"
        end

        it "should set :name to the title if :name is not present for non-builtin types" do
            resource = Puppet::Resource.new :foo, "bar"
            resource.to_hash[:name].should == "bar"
        end
    end

    describe "when serializing" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
            @resource["one"] = "test"
            @resource["two"] = "other"
        end

        it "should be able to be dumped to yaml" do
            proc { YAML.dump(@resource) }.should_not raise_error
        end

        it "should produce an equivalent yaml object" do
            text = YAML.dump(@resource)

            newresource = YAML.load(text)
            newresource.title.should == @resource.title
            newresource.type.should == @resource.type
            %w{one two}.each do |param|
                newresource[param].should == @resource[param]
            end
        end
    end

    describe "when converting to a RAL resource" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
            @resource["one"] = "test"
            @resource["two"] = "other"
        end

        it "should use the resource type's :create method to create the resource if the resource is of a builtin type" do
            type = mock 'resource type'
            type.expects(:new).with(@resource).returns(:myresource)
            Puppet::Type.expects(:type).with(@resource.type).returns(type)
            @resource.to_ral.should == :myresource
        end

        it "should convert to a component instance if the resource type is not of a builtin type" do
            component = mock 'component type'
            Puppet::Type::Component.expects(:new).with(@resource).returns "meh"

            Puppet::Type.expects(:type).with(@resource.type).returns(nil)
            @resource.to_ral.should == "meh"
        end
    end

    it "should be able to convert itself to Puppet code" do
        Puppet::Resource.new("one::two", "/my/file").should respond_to(:to_manifest)
    end

    describe "when converting to puppet code" do
        before do
            @resource = Puppet::Resource.new("one::two", "/my/file", :parameters => {:noop => true, :foo => %w{one two}})
        end

        it "should print the type and title" do
            @resource.to_manifest.should be_include("one::two { '/my/file':\n")
        end

        it "should print each parameter, with the value single-quoted" do
            @resource.to_manifest.should be_include("    noop => 'true'")
        end

        it "should print array values appropriately" do
            @resource.to_manifest.should be_include("    foo => ['one','two']")
        end
    end

    it "should be able to convert itself to a TransObject instance" do
        Puppet::Resource.new("one::two", "/my/file").should respond_to(:to_trans)
    end

    describe "when converting to a TransObject" do
        describe "and the resource is not an instance of a builtin type" do
            before do
                @resource = Puppet::Resource.new("foo", "bar")
            end

            it "should return a simple TransBucket if it is not an instance of a builtin type" do
                bucket = @resource.to_trans
                bucket.should be_instance_of(Puppet::TransBucket)
                bucket.type.should == @resource.type
                bucket.name.should == @resource.title
            end

            it "should copy over the resource's file" do
                @resource.file = "/foo/bar"
                @resource.to_trans.file.should == "/foo/bar"
            end

            it "should copy over the resource's line" do
                @resource.line = 50
                @resource.to_trans.line.should == 50
            end
        end

        describe "and the resource is an instance of a builtin type" do
            before do
                @resource = Puppet::Resource.new("file", "bar")
            end

            it "should return a TransObject if it is an instance of a builtin resource type" do
                trans = @resource.to_trans
                trans.should be_instance_of(Puppet::TransObject)
                trans.type.should == "file"
                trans.name.should == @resource.title
            end

            it "should copy over the resource's file" do
                @resource.file = "/foo/bar"
                @resource.to_trans.file.should == "/foo/bar"
            end

            it "should copy over the resource's line" do
                @resource.line = 50
                @resource.to_trans.line.should == 50
            end

            # Only TransObjects support tags, annoyingly
            it "should copy over the resource's tags" do
                @resource.tag "foo"
                @resource.to_trans.tags.should == @resource.tags
            end

            it "should copy the resource's parameters into the transobject and convert the parameter name to a string" do
                @resource[:foo] = "bar"
                @resource.to_trans["foo"].should == "bar"
            end

            it "should be able to copy arrays of values" do
                @resource[:foo] = %w{yay fee}
                @resource.to_trans["foo"].should == %w{yay fee}
            end

            it "should reduce single-value arrays to just a value" do
                @resource[:foo] = %w{yay}
                @resource.to_trans["foo"].should == "yay"
            end

            it "should convert resource references into the backward-compatible form" do
                @resource[:foo] = Puppet::Resource::Reference.new(:file, "/f")
                @resource.to_trans["foo"].should == %w{file /f}
            end

            it "should convert resource references into the backward-compatible form even when within arrays" do
                @resource[:foo] = ["a", Puppet::Resource::Reference.new(:file, "/f")]
                @resource.to_trans["foo"].should == ["a", %w{file /f}]
            end
        end
    end

    describe "when converting to pson" do
        confine "Missing 'pson' library" => Puppet.features.pson?

        def pson_output_should
            @resource.class.expects(:pson_create).with { |hash| yield hash }
        end

        it "should include the pson util module" do
            Puppet::Resource.metaclass.ancestors.should be_include(Puppet::Util::Pson)
        end

        # LAK:NOTE For all of these tests, we convert back to the resource so we can
        # trap the actual data structure then.

        it "should set its type to the provided type" do
            Puppet::Resource.from_pson(PSON.parse(Puppet::Resource.new("File", "/foo").to_pson)).type.should == "File"
        end

        it "should set its title to the provided title" do
            Puppet::Resource.from_pson(PSON.parse(Puppet::Resource.new("File", "/foo").to_pson)).title.should == "/foo"
        end

        it "should include all tags from the resource" do
            resource = Puppet::Resource.new("File", "/foo")
            resource.tag("yay")

            Puppet::Resource.from_pson(PSON.parse(resource.to_pson)).tags.should == resource.tags
        end

        it "should include the file if one is set" do
            resource = Puppet::Resource.new("File", "/foo")
            resource.file = "/my/file"

            Puppet::Resource.from_pson(PSON.parse(resource.to_pson)).file.should == "/my/file"
        end

        it "should include the line if one is set" do
            resource = Puppet::Resource.new("File", "/foo")
            resource.line = 50

            Puppet::Resource.from_pson(PSON.parse(resource.to_pson)).line.should == 50
        end

        it "should include the 'exported' value if one is set" do
            resource = Puppet::Resource.new("File", "/foo")
            resource.exported = true

            Puppet::Resource.from_pson(PSON.parse(resource.to_pson)).exported.should be_true
        end

        it "should set 'exported' to false if no value is set" do
            resource = Puppet::Resource.new("File", "/foo")

            Puppet::Resource.from_pson(PSON.parse(resource.to_pson)).exported.should be_false
        end

        it "should set all of its parameters as the 'parameters' entry" do
            resource = Puppet::Resource.new("File", "/foo")
            resource[:foo] = %w{bar eh}
            resource[:fee] = %w{baz}

            result = Puppet::Resource.from_pson(PSON.parse(resource.to_pson))
            result["foo"].should == %w{bar eh}
            result["fee"].should == %w{baz}
        end
    end

    describe "when converting from pson" do
        confine "Missing 'pson' library" => Puppet.features.pson?

        def pson_result_should
            Puppet::Resource.expects(:new).with { |hash| yield hash }
        end

        before do
            @data = {
                'type' => "file",
                'title' => "yay",
            }
        end

        it "should set its type to the provided type" do
            Puppet::Resource.from_pson(@data).type.should == "File"
        end

        it "should set its title to the provided title" do
            Puppet::Resource.from_pson(@data).title.should == "yay"
        end

        it "should tag the resource with any provided tags" do
            @data['tags'] = %w{foo bar}
            resource = Puppet::Resource.from_pson(@data)
            resource.tags.should be_include("foo")
            resource.tags.should be_include("bar")
        end

        it "should set its file to the provided file" do
            @data['file'] = "/foo/bar"
            Puppet::Resource.from_pson(@data).file.should == "/foo/bar"
        end

        it "should set its line to the provided line" do
            @data['line'] = 50
            Puppet::Resource.from_pson(@data).line.should == 50
        end

        it "should 'exported' to true if set in the pson data" do
            @data['exported'] = true
            Puppet::Resource.from_pson(@data).exported.should be_true
        end

        it "should 'exported' to false if not set in the pson data" do
            Puppet::Resource.from_pson(@data).exported.should be_false
        end

        it "should fail if no title is provided" do
            @data.delete('title')
            lambda { Puppet::Resource.from_pson(@data) }.should raise_error(ArgumentError)
        end

        it "should fail if no type is provided" do
            @data.delete('type')
            lambda { Puppet::Resource.from_pson(@data) }.should raise_error(ArgumentError)
        end

        it "should set each of the provided parameters" do
            @data['parameters'] = {'foo' => %w{one two}, 'fee' => %w{three four}}
            resource = Puppet::Resource.from_pson(@data)
            resource['foo'].should == %w{one two}
            resource['fee'].should == %w{three four}
        end

        it "should convert single-value array parameters to normal values" do
            @data['parameters'] = {'foo' => %w{one}}
            resource = Puppet::Resource.from_pson(@data)
            resource['foo'].should == %w{one}
        end
    end

    describe "it should implement to_resource" do
        resource = Puppet::Resource.new("file", "/my/file")
        resource.to_resource.should == resource
    end

    describe "because it is an indirector model" do
        it "should include Puppet::Indirector" do
            Puppet::Resource.should be_is_a(Puppet::Indirector)
        end

        it "should have a default terminus" do
            Puppet::Resource.indirection.terminus_class.should == :ral
        end

        it "should have a name" do
            Puppet::Resource.new("file", "/my/file").name.should == "File//my/file"
        end
    end
end
