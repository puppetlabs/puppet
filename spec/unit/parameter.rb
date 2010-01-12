#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/parameter'

describe Puppet::Parameter do
    before do
        @class = Class.new(Puppet::Parameter) do
            @name = :foo
        end
        @class.initvars
        @resource = mock 'resource'
        @resource.stub_everything
        @parameter = @class.new :resource => @resource
    end

    it "should create a value collection" do
        @class = Class.new(Puppet::Parameter)
        @class.value_collection.should be_nil
        @class.initvars
        @class.value_collection.should be_instance_of(Puppet::Parameter::ValueCollection)
    end

    it "should be able to use cached attributes" do
        Puppet::Parameter.ancestors.should be_include(Puppet::Util::Cacher)
    end

    it "should use the resource catalog for expiration" do
        catalog = mock 'catalog'
        @resource.stubs(:catalog).returns catalog
        @parameter.expirer.should equal(catalog)
    end

    [:line, :file, :version].each do |data|
        it "should return its resource's #{data} as its #{data}" do
            @resource.expects(data).returns "foo"
            @parameter.send(data).should == "foo"
        end
    end

    it "should return the resource's tags plus its name as its tags" do
        @resource.expects(:tags).returns %w{one two}
        @parameter.tags.should == %w{one two foo}
    end

    it "should provide source_descriptors" do
        @resource.expects(:line).returns 10
        @resource.expects(:file).returns "file"
        @resource.expects(:tags).returns %w{one two}
        @resource.expects(:version).returns 50
        @parameter.source_descriptors.should == {:tags=>["one", "two", "foo"], :path=>"//foo", :version=>50, :file => "file", :line => 10}
    end

    describe "when returning the value" do
        it "should return nil if no value is set" do
            @parameter.value.should be_nil
        end

        it "should validate the value" do
            @parameter.expects(:validate).with("foo")
            @parameter.value = "foo"
        end

        it "should munge the value and use any result as the actual value" do
            @parameter.expects(:munge).with("foo").returns "bar"
            @parameter.value = "foo"
            @parameter.value.should == "bar"
        end

        it "should unmunge the value when accessing the actual value" do
            @parameter.class.unmunge do |value| value.to_sym end
            @parameter.value = "foo"
            @parameter.value.should == :foo
        end

        it "should return the actual value by default when unmunging" do
            @parameter.unmunge("bar").should == "bar"
        end

        it "should return any set value" do
            @parameter.value = "foo"
            @parameter.value.should == "foo"
        end
    end

    describe "when validating values" do
        it "should do nothing if no values or regexes have been defined" do
            @parameter.validate("foo")
        end

        it "should catch abnormal failures thrown during validation" do
            @class.validate { |v| raise "This is broken" }
            lambda { @parameter.validate("eh") }.should raise_error(Puppet::DevError)
        end

        it "should fail if the value is not a defined value or alias and does not match a regex" do
            @class.newvalues :foo
            lambda { @parameter.validate("bar") }.should raise_error(Puppet::Error)
        end

        it "should succeed if the value is one of the defined values" do
            @class.newvalues :foo
            lambda { @parameter.validate(:foo) }.should_not raise_error(ArgumentError)
        end

        it "should succeed if the value is one of the defined values even if the definition uses a symbol and the validation uses a string" do
            @class.newvalues :foo
            lambda { @parameter.validate("foo") }.should_not raise_error(ArgumentError)
        end

        it "should succeed if the value is one of the defined values even if the definition uses a string and the validation uses a symbol" do
            @class.newvalues "foo"
            lambda { @parameter.validate(:foo) }.should_not raise_error(ArgumentError)
        end

        it "should succeed if the value is one of the defined aliases" do
            @class.newvalues :foo
            @class.aliasvalue :bar, :foo
            lambda { @parameter.validate("bar") }.should_not raise_error(ArgumentError)
        end

        it "should succeed if the value matches one of the regexes" do
            @class.newvalues %r{\d}
            lambda { @parameter.validate("10") }.should_not raise_error(ArgumentError)
        end
    end

    describe "when munging values" do
        it "should do nothing if no values or regexes have been defined" do
            @parameter.munge("foo").should == "foo"
        end

        it "should catch abnormal failures thrown during munging" do
            @class.munge { |v| raise "This is broken" }
            lambda { @parameter.munge("eh") }.should raise_error(Puppet::DevError)
        end

        it "should return return any matching defined values" do
            @class.newvalues :foo, :bar
            @parameter.munge("foo").should == :foo
        end

        it "should return any matching aliases" do
            @class.newvalues :foo
            @class.aliasvalue :bar, :foo
            @parameter.munge("bar").should == :foo
        end

        it "should return the value if it matches a regex" do
            @class.newvalues %r{\w}
            @parameter.munge("bar").should == "bar"
        end

        it "should return the value if no other option is matched" do
            @class.newvalues :foo
            @parameter.munge("bar").should == "bar"
        end
    end
end

describe Puppet::Parameter::ValueCollection do
    before do
        @collection = Puppet::Parameter::ValueCollection.new
    end

    it "should have a method for defining new values" do
        @collection.should respond_to(:newvalues)
    end

    it "should have a method for adding individual values" do
        @collection.should respond_to(:newvalue)
    end

    it "should be able to retrieve individual values" do
        value = @collection.newvalue(:foo)
        @collection.value(:foo).should equal(value)
    end

    it "should be able to add an individual value with a block" do
        @collection.newvalue(:foo) { raise "testing" }
        @collection.value(:foo).block.should be_instance_of(Proc)
    end

    it "should be able to add values that are empty strings" do
        lambda { @collection.newvalue('') }.should_not raise_error
    end

    it "should be able to add values that are empty strings" do
        value = @collection.newvalue('')
        @collection.match?('').should equal(value)
    end

    it "should set :call to :none when adding a value with no block" do
        value = @collection.newvalue(:foo)
        value.call.should == :none
    end

    describe "when adding a value with a block" do
        it "should set the method name to 'set_' plus the value name" do
            value = @collection.newvalue(:myval) { raise "testing" }
            value.method.should == "set_myval"
        end
    end

    it "should be able to add an individual value with options" do
        value = @collection.newvalue(:foo, :call => :bar)
        value.call.should == :bar
    end

    it "should have a method for validating a value" do
        @collection.should respond_to(:validate)
    end

    it "should have a method for munging a value" do
        @collection.should respond_to(:munge)
    end

    it "should be able to generate documentation when it has both values and regexes" do
        @collection.newvalues :foo, "bar", %r{test}
        @collection.doc.should be_instance_of(String)
    end

    it "should correctly generate documentation for values" do
        @collection.newvalues :foo
        @collection.doc.should be_include("Valid values are ``foo``")
    end

    it "should correctly generate documentation for regexes" do
        @collection.newvalues %r{\w+}
        @collection.doc.should be_include("Values can match ``/\\w+/``")
    end

    it "should be able to find the first matching value" do
        @collection.newvalues :foo, :bar
        @collection.match?("foo").should be_instance_of(Puppet::Parameter::ValueCollection::Value)
    end

    it "should be able to match symbols" do
        @collection.newvalues :foo, :bar
        @collection.match?(:foo).should be_instance_of(Puppet::Parameter::ValueCollection::Value)
    end

    it "should be able to match symbols when a regex is provided" do
        @collection.newvalues %r{.}
        @collection.match?(:foo).should be_instance_of(Puppet::Parameter::ValueCollection::Value)
    end

    it "should be able to match values using regexes" do
        @collection.newvalues %r{.}
        @collection.match?("foo").should_not be_nil
    end

    it "should prefer value matches to regex matches" do
        @collection.newvalues %r{.}, :foo
        @collection.match?("foo").name.should == :foo
    end

    describe "when validating values" do
        it "should do nothing if no values or regexes have been defined" do
            @collection.validate("foo")
        end

        it "should fail if the value is not a defined value or alias and does not match a regex" do
            @collection.newvalues :foo
            lambda { @collection.validate("bar") }.should raise_error(ArgumentError)
        end

        it "should succeed if the value is one of the defined values" do
            @collection.newvalues :foo
            lambda { @collection.validate(:foo) }.should_not raise_error(ArgumentError)
        end

        it "should succeed if the value is one of the defined values even if the definition uses a symbol and the validation uses a string" do
            @collection.newvalues :foo
            lambda { @collection.validate("foo") }.should_not raise_error(ArgumentError)
        end

        it "should succeed if the value is one of the defined values even if the definition uses a string and the validation uses a symbol" do
            @collection.newvalues "foo"
            lambda { @collection.validate(:foo) }.should_not raise_error(ArgumentError)
        end

        it "should succeed if the value is one of the defined aliases" do
            @collection.newvalues :foo
            @collection.aliasvalue :bar, :foo
            lambda { @collection.validate("bar") }.should_not raise_error(ArgumentError)
        end

        it "should succeed if the value matches one of the regexes" do
            @collection.newvalues %r{\d}
            lambda { @collection.validate("10") }.should_not raise_error(ArgumentError)
        end
    end

    describe "when munging values" do
        it "should do nothing if no values or regexes have been defined" do
            @collection.munge("foo").should == "foo"
        end

        it "should return return any matching defined values" do
            @collection.newvalues :foo, :bar
            @collection.munge("foo").should == :foo
        end

        it "should return any matching aliases" do
            @collection.newvalues :foo
            @collection.aliasvalue :bar, :foo
            @collection.munge("bar").should == :foo
        end

        it "should return the value if it matches a regex" do
            @collection.newvalues %r{\w}
            @collection.munge("bar").should == "bar"
        end

        it "should return the value if no other option is matched" do
            @collection.newvalues :foo
            @collection.munge("bar").should == "bar"
        end
    end
end

describe Puppet::Parameter::ValueCollection::Value do
    it "should require a name" do
        lambda { Puppet::Parameter::ValueCollection::Value.new }.should raise_error(ArgumentError)
    end

    it "should set its name" do
        Puppet::Parameter::ValueCollection::Value.new(:foo).name.should == :foo
    end

    it "should support regexes as names" do
        lambda { Puppet::Parameter::ValueCollection::Value.new(%r{foo}) }.should_not raise_error
    end

    it "should mark itself as a regex if its name is a regex" do
        Puppet::Parameter::ValueCollection::Value.new(%r{foo}).should be_regex
    end

    it "should always convert its name to a symbol if it is not a regex" do
        Puppet::Parameter::ValueCollection::Value.new("foo").name.should == :foo
        Puppet::Parameter::ValueCollection::Value.new(true).name.should == :true
    end

    it "should support adding aliases" do
        Puppet::Parameter::ValueCollection::Value.new("foo").should respond_to(:alias)
    end

    it "should be able to return its aliases" do
        value = Puppet::Parameter::ValueCollection::Value.new("foo")
        value.alias("bar")
        value.alias("baz")
        value.aliases.should == [:bar, :baz]
    end

    [:block, :call, :method, :event, :required_features].each do |attr|
        it "should support a #{attr} attribute" do
            value = Puppet::Parameter::ValueCollection::Value.new("foo")
            value.should respond_to(attr.to_s + "=")
            value.should respond_to(attr)
        end
    end

    it "should default to :instead for :call if a block is provided" do
        Puppet::Parameter::ValueCollection::Value.new("foo").call.should == :instead
    end

    it "should always return events as symbols" do
        value = Puppet::Parameter::ValueCollection::Value.new("foo")
        value.event = "foo_test"
        value.event.should == :foo_test
    end

    describe "when matching" do
        describe "a regex" do
            it "should return true if the regex matches the value" do
                Puppet::Parameter::ValueCollection::Value.new(/\w/).should be_match("foo")
            end

            it "should return false if the regex does not match the value" do
                Puppet::Parameter::ValueCollection::Value.new(/\d/).should_not be_match("foo")
            end
        end

        describe "a non-regex" do
            it "should return true if the value, converted to a symbol, matches the name" do
                Puppet::Parameter::ValueCollection::Value.new("foo").should be_match("foo")
                Puppet::Parameter::ValueCollection::Value.new(:foo).should be_match(:foo)
                Puppet::Parameter::ValueCollection::Value.new(:foo).should be_match("foo")
                Puppet::Parameter::ValueCollection::Value.new("foo").should be_match(:foo)
            end

            it "should return false if the value, converted to a symbol, does not match the name" do
                Puppet::Parameter::ValueCollection::Value.new(:foo).should_not be_match(:bar)
            end

            it "should return true if any of its aliases match" do
                value = Puppet::Parameter::ValueCollection::Value.new("foo")
                value.alias("bar")
                value.should be_match("bar")
            end
        end
    end
end
