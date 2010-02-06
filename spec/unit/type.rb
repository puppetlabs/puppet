#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Type do
    it "should include the Cacher module" do
        Puppet::Type.ancestors.should be_include(Puppet::Util::Cacher)
    end

    it "should consider a parameter to be valid if it is a valid parameter" do
        Puppet::Type.type(:mount).should be_valid_parameter(:path)
    end

    it "should consider a parameter to be valid if it is a valid property" do
        Puppet::Type.type(:mount).should be_valid_parameter(:fstype)
    end

    it "should consider a parameter to be valid if it is a valid metaparam" do
        Puppet::Type.type(:mount).should be_valid_parameter(:noop)
    end

    it "should use its catalog as its expirer" do
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:mount).new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
        resource.catalog = catalog
        resource.expirer.should equal(catalog)
    end

    it "should do nothing when asked to expire when it has no catalog" do
        resource = Puppet::Type.type(:mount).new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
        lambda { resource.expire }.should_not raise_error
    end

    it "should be able to retrieve a property by name" do
        resource = Puppet::Type.type(:mount).new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
        resource.property(:fstype).must be_instance_of(Puppet::Type.type(:mount).attrclass(:fstype))
    end

    it "should be able to retrieve a parameter by name" do
        resource = Puppet::Type.type(:mount).new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
        resource.parameter(:name).must be_instance_of(Puppet::Type.type(:mount).attrclass(:name))
    end

    it "should be able to retrieve a property by name using the :parameter method" do
        resource = Puppet::Type.type(:mount).new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
        resource.parameter(:fstype).must be_instance_of(Puppet::Type.type(:mount).attrclass(:fstype))
    end

    it "should be able to retrieve all set properties" do
        resource = Puppet::Type.type(:mount).new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
        props = resource.properties
        props.should_not be_include(nil)
        [:fstype, :ensure, :pass].each do |name|
            props.should be_include(resource.parameter(name))
        end
    end

    it "should have a method for setting default values for resources" do
        Puppet::Type.type(:mount).new(:name => "foo").should respond_to(:set_default)
    end

    it "should do nothing for attributes that have no defaults and no specified value" do
        Puppet::Type.type(:mount).new(:name => "foo").parameter(:noop).should be_nil
    end

    it "should have a method for adding tags" do
        Puppet::Type.type(:mount).new(:name => "foo").should respond_to(:tags)
    end

    it "should use the tagging module" do
        Puppet::Type.type(:mount).ancestors.should be_include(Puppet::Util::Tagging)
    end

    it "should delegate to the tagging module when tags are added" do
        resource = Puppet::Type.type(:mount).new(:name => "foo")
        resource.stubs(:tag).with(:mount)

        resource.expects(:tag).with(:tag1, :tag2)

        resource.tags = [:tag1,:tag2]
    end

    it "should add the current type as tag" do
        resource = Puppet::Type.type(:mount).new(:name => "foo")
        resource.stubs(:tag)

        resource.expects(:tag).with(:mount)

        resource.tags = [:tag1,:tag2]
    end

    it "should have a method to know if the resource is exported" do
        Puppet::Type.type(:mount).new(:name => "foo").should respond_to(:exported?)
    end

    it "should have a method to know if the resource is virtual" do
        Puppet::Type.type(:mount).new(:name => "foo").should respond_to(:virtual?)
    end

    it "should consider its version to be its catalog version" do
        resource = Puppet::Type.type(:mount).new(:name => "foo")
        catalog = Puppet::Resource::Catalog.new
        catalog.version = 50
        catalog.add_resource resource

        resource.version.should == 50
    end

    it "should consider its version to be zero if it has no catalog" do
        Puppet::Type.type(:mount).new(:name => "foo").version.should == 0
    end

    it "should provide source_descriptors" do
        resource = Puppet::Type.type(:mount).new(:name => "foo")
        catalog = Puppet::Resource::Catalog.new
        catalog.version = 50
        catalog.add_resource resource

        resource.source_descriptors.should == {:version=>50, :tags=>["mount", "foo"], :path=>"/Mount[foo]"}
    end

    it "should consider its type to be the name of its class" do
        Puppet::Type.type(:mount).new(:name => "foo").type.should == :mount
    end

    describe "when creating an event" do
        before do
            @resource = Puppet::Type.type(:mount).new :name => "foo"
        end

        it "should have the resource's reference as the resource" do
            @resource.event.resource.should == "Mount[foo]"
        end

        it "should have the resource's log level as the default log level" do
            @resource[:loglevel] = :warning
            @resource.event.default_log_level.should == :warning
        end

        {:file => "/my/file", :line => 50, :tags => %{foo bar}, :version => 50}.each do |attr, value|
            it "should set the #{attr}" do
                @resource.stubs(attr).returns value
                @resource.event.send(attr).should == value
            end
        end

        it "should allow specification of event attributes" do
            @resource.event(:status => "noop").status.should == "noop"
        end
    end

    describe "when choosing a default provider" do
        it "should choose the provider with the highest specificity" do
            # Make a fake type
            type = Puppet::Type.newtype(:defaultprovidertest) do
                newparam(:name) do end
            end

            basic = type.provide(:basic) {}
            greater = type.provide(:greater) {}

            basic.stubs(:specificity).returns 1
            greater.stubs(:specificity).returns 2

            type.defaultprovider.should equal(greater)
        end
    end

    describe "when initializing" do
        describe "and passed a TransObject" do
            it "should fail" do
                trans = Puppet::TransObject.new("/foo", :mount)
                lambda { Puppet::Type.type(:mount).new(trans) }.should raise_error(Puppet::DevError)
            end
        end

        describe "and passed a Puppet::Resource instance" do
            it "should set its title to the title of the resource if the resource type is equal to the current type" do
                resource = Puppet::Resource.new(:mount, "/foo", :parameters => {:name => "/other"})
                Puppet::Type.type(:mount).new(resource).title.should == "/foo"
            end

            it "should set its title to the resource reference if the resource type is not equal to the current type" do
                resource = Puppet::Resource.new(:user, "foo")
                Puppet::Type.type(:mount).new(resource).title.should == "User[foo]"
            end

            [:line, :file, :catalog, :exported, :virtual].each do |param|
                it "should copy '#{param}' from the resource if present" do
                    resource = Puppet::Resource.new(:mount, "/foo")
                    resource.send(param.to_s + "=", "foo")
                    resource.send(param.to_s + "=", "foo")
                    Puppet::Type.type(:mount).new(resource).send(param).should == "foo"
                end
            end

            it "should copy any tags from the resource" do
                resource = Puppet::Resource.new(:mount, "/foo")
                resource.tag "one", "two"
                tags = Puppet::Type.type(:mount).new(resource).tags
                tags.should be_include("one")
                tags.should be_include("two")
            end

            it "should copy the resource's parameters as its own" do
                resource = Puppet::Resource.new(:mount, "/foo", :parameters => {:atboot => true, :fstype => "boo"})
                params = Puppet::Type.type(:mount).new(resource).to_hash
                params[:fstype].should == "boo"
                params[:atboot].should == true
            end
        end

        describe "and passed a Hash" do
            it "should extract the title from the hash" do
                Puppet::Type.type(:mount).new(:title => "/yay").title.should == "/yay"
            end

            it "should work when hash keys are provided as strings" do
                Puppet::Type.type(:mount).new("title" => "/yay").title.should == "/yay"
            end

            it "should work when hash keys are provided as symbols" do
                Puppet::Type.type(:mount).new(:title => "/yay").title.should == "/yay"
            end

            it "should use the name from the hash as the title if no explicit title is provided" do
                Puppet::Type.type(:mount).new(:name => "/yay").title.should == "/yay"
            end

            it "should use the Resource Type's namevar to determine how to find the name in the hash" do
                Puppet::Type.type(:file).new(:path => "/yay").title.should == "/yay"
            end

            it "should fail if the namevar is not equal to :name and both :name and the namevar are provided" do
                lambda { Puppet::Type.type(:file).new(:path => "/yay", :name => "/foo") }.should raise_error(Puppet::Error)
                @type.stubs(:namevar).returns :myname
            end

            [:catalog].each do |param|
                it "should extract '#{param}' from the hash if present" do
                    Puppet::Type.type(:mount).new(:name => "/yay", param => "foo").send(param).should == "foo"
                end
            end

            it "should use any remaining hash keys as its parameters" do
                resource = Puppet::Type.type(:mount).new(:title => "/foo", :catalog => "foo", :atboot => true, :fstype => "boo")
                resource[:fstype].must == "boo"
                resource[:atboot].must == true
            end
        end

        it "should fail if any invalid attributes have been provided" do
            lambda { Puppet::Type.type(:mount).new(:title => "/foo", :nosuchattr => "whatever") }.should raise_error(Puppet::Error)
        end

        it "should set its name to the resource's title if the resource does not have a :name or namevar parameter set" do
            resource = Puppet::Resource.new(:mount, "/foo")

            Puppet::Type.type(:mount).new(resource).name.should == "/foo"
        end

        it "should fail if no title, name, or namevar are provided" do
            lambda { Puppet::Type.type(:file).new(:atboot => true) }.should raise_error(Puppet::Error)
        end

        it "should set the attributes in the order returned by the class's :allattrs method" do
            Puppet::Type.type(:mount).stubs(:allattrs).returns([:name, :atboot, :noop])
            resource = Puppet::Resource.new(:mount, "/foo", :parameters => {:name => "myname", :atboot => "myboot", :noop => "whatever"})

            set = []

            Puppet::Type.type(:mount).any_instance.stubs(:newattr).with do |param, hash|
                set << param
                true
            end

            Puppet::Type.type(:mount).new(resource)

            set[-1].should == :noop
            set[-2].should == :atboot
        end

        it "should always set the name and then default provider before anything else" do
            Puppet::Type.type(:mount).stubs(:allattrs).returns([:provider, :name, :atboot])
            resource = Puppet::Resource.new(:mount, "/foo", :parameters => {:name => "myname", :atboot => "myboot"})

            set = []

            Puppet::Type.type(:mount).any_instance.stubs(:newattr).with do |param, hash|
                set << param
                true
            end

            Puppet::Type.type(:mount).new(resource)
            set[0].should == :name
            set[1].should == :provider
        end

        # This one is really hard to test :/
        it "should each default immediately if no value is provided" do
            defaults = []
            Puppet::Type.type(:package).any_instance.stubs(:set_default).with { |value| defaults << value; true }

            Puppet::Type.type(:package).new :name => "whatever"

            defaults[0].should == :provider
        end

        it "should retain a copy of the originally provided parameters" do
            Puppet::Type.type(:mount).new(:name => "foo", :atboot => true, :noop => false).original_parameters.should == {:atboot => true, :noop => false}
        end

        it "should delete the name via the namevar from the originally provided parameters" do
            Puppet::Type.type(:file).new(:name => "/foo").original_parameters[:path].should be_nil
        end
    end

    it "should have a class method for converting a hash into a Puppet::Resource instance" do
        Puppet::Type.type(:mount).must respond_to(:hash2resource)
    end

    describe "when converting a hash to a Puppet::Resource instance" do
        before do
            @type = Puppet::Type.type(:mount)
        end

        it "should treat a :title key as the title of the resource" do
            @type.hash2resource(:name => "/foo", :title => "foo").title.should == "foo"
        end

        it "should use the name from the hash as the title if no explicit title is provided" do
            @type.hash2resource(:name => "foo").title.should == "foo"
        end

        it "should use the Resource Type's namevar to determine how to find the name in the hash" do
            @type.stubs(:namevar).returns :myname

            @type.hash2resource(:myname => "foo").title.should == "foo"
        end

        it "should fail if the namevar is not equal to :name and both :name and the namevar are provided" do
            @type.stubs(:namevar).returns :myname

            lambda { @type.hash2resource(:myname => "foo", :name => 'bar') }.should raise_error(Puppet::Error)
        end

        [:catalog].each do |attr|
            it "should use any provided #{attr}" do
                @type.hash2resource(:name => "foo", attr => "eh").send(attr).should == "eh"
            end
        end

        it "should set all provided parameters on the resource" do
            @type.hash2resource(:name => "foo", :fstype => "boo", :boot => "fee").to_hash.should == {:name => "foo", :fstype => "boo", :boot => "fee"}
        end

        it "should not set the title as a parameter on the resource" do
            @type.hash2resource(:name => "foo", :title => "eh")[:title].should be_nil
        end

        it "should not set the catalog as a parameter on the resource" do
            @type.hash2resource(:name => "foo", :catalog => "eh")[:catalog].should be_nil
        end

        it "should treat hash keys equivalently whether provided as strings or symbols" do
            resource = @type.hash2resource("name" => "foo", "title" => "eh", "fstype" => "boo")
            resource.title.should == "eh"
            resource[:name].should == "foo"
            resource[:fstype].should == "boo"
        end
    end

    describe "when retrieving current property values" do
        before do
            @resource = Puppet::Type.type(:mount).new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
            @resource.property(:ensure).stubs(:retrieve).returns :absent
        end

        it "should fail if its provider is unsuitable" do
            @resource = Puppet::Type.type(:mount).new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
            @resource.provider.class.expects(:suitable?).returns false
            lambda { @resource.retrieve }.should raise_error(Puppet::Error)
        end

        it "should return a Puppet::Resource instance with its type and title set appropriately" do
            result = @resource.retrieve
            result.should be_instance_of(Puppet::Resource)
            result.type.should == "Mount"
            result.title.should == "foo"
        end

        it "should set the name of the returned resource if its own name and title differ" do
            @resource[:name] = "my name"
            @resource.title = "other name"
            @resource.retrieve[:name].should == "my name"
        end

        it "should provide a value for all set properties" do
            values = @resource.retrieve
            [:ensure, :fstype, :pass].each { |property| values[property].should_not be_nil }
        end

        it "should provide a value for 'ensure' even if no desired value is provided" do
            @resource = Puppet::Type.type(:file).new(:path => "/my/file/that/can't/exist")
        end

        it "should not call retrieve on non-ensure properties if the resource is absent and should consider the property absent" do
            @resource.property(:ensure).expects(:retrieve).returns :absent
            @resource.property(:fstype).expects(:retrieve).never
            @resource.retrieve[:fstype].should == :absent
        end

        it "should include the result of retrieving each property's current value if the resource is present" do
            @resource.property(:ensure).expects(:retrieve).returns :present
            @resource.property(:fstype).expects(:retrieve).returns 15
            @resource.retrieve[:fstype] == 15
        end
    end


    describe "when in a catalog" do
        before do
            @catalog = Puppet::Resource::Catalog.new
            @container = Puppet::Type.type(:component).new(:name => "container")
            @one = Puppet::Type.type(:file).new(:path => "/file/one")
            @two = Puppet::Type.type(:file).new(:path => "/file/two")

            @catalog.add_resource @container
            @catalog.add_resource @one
            @catalog.add_resource @two
            @catalog.add_edge @container, @one
            @catalog.add_edge @container, @two
        end

        it "should have no parent if there is no in edge" do
            @container.parent.should be_nil
        end

        it "should set its parent to its in edge" do
            @one.parent.ref.should == @container.ref
        end

        after do
            @catalog.clear(true)
        end
    end

    describe "when managing relationships" do
    end
end

describe Puppet::Type::RelationshipMetaparam do
    it "should be a subclass of Puppet::Parameter" do
        Puppet::Type::RelationshipMetaparam.superclass.should equal(Puppet::Parameter)
    end

    it "should be able to produce a list of subclasses" do
        Puppet::Type::RelationshipMetaparam.should respond_to(:subclasses)
    end

    describe "when munging relationships" do
        before do
            @resource = Puppet::Type.type(:mount).new :name => "/foo"
            @metaparam = Puppet::Type.metaparamclass(:require).new :resource => @resource
        end

        it "should accept Puppet::Resource instances" do
            ref = Puppet::Resource.new(:file, "/foo")
            @metaparam.munge(ref)[0].should equal(ref)
        end

        it "should turn any string into a Puppet::Resource" do
            @metaparam.munge("File[/ref]")[0].should be_instance_of(Puppet::Resource)
        end
    end

    it "should be able to validate relationships" do
        Puppet::Type.metaparamclass(:require).new(:resource => mock("resource")).should respond_to(:validate_relationship)
    end

    it "should fail if any specified resource is not found in the catalog" do
        catalog = mock 'catalog'
        resource = stub 'resource', :catalog => catalog, :ref => "resource"

        param = Puppet::Type.metaparamclass(:require).new(:resource => resource, :value => %w{Foo[bar] Class[test]})

        catalog.expects(:resource).with("Foo[bar]").returns "something"
        catalog.expects(:resource).with("Class[Test]").returns nil

        param.expects(:fail).with { |string| string.include?("Class[Test]") }

        param.validate_relationship
    end
end
