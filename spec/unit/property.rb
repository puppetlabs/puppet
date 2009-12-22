#!/usr/bin/env ruby"

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/property'

describe Puppet::Property do
    before do
        @class = Class.new(Puppet::Property) do
            @name = :foo
        end
        @class.initvars
        @provider = mock 'provider'
        @resource = stub 'resource', :provider => @provider
        @resource.stub_everything
        @property = @class.new :resource => @resource
    end

    it "should be able to look up the modified name for a given value" do
        @class.newvalue(:foo)
        @class.value_name("foo").should == :foo
    end

    it "should be able to look up the modified name for a given value matching a regex" do
        @class.newvalue(%r{.})
        @class.value_name("foo").should == %r{.}
    end

    it "should be able to look up a given value option" do
        @class.newvalue(:foo, :event => :whatever)
        @class.value_option(:foo, :event).should == :whatever
    end

    it "should be able to specify required features" do
        @class.should respond_to(:required_features=)
    end

    {"one" => [:one],:one => [:one],%w{a} => [:a],[:b] => [:b],%w{one two} => [:one,:two],[:a,:b] => [:a,:b]}.each { |in_value,out_value|
        it "should always convert required features into an array of symbols (e.g. #{in_value.inspect} --> #{out_value.inspect})" do
            @class.required_features = in_value
            @class.required_features.should == out_value
        end
    }

    it "should be able to shadow metaparameters" do
        @property.must respond_to(:shadow)
    end

    describe "when shadowing metaparameters" do
        before do
            @shadow_class = Class.new(Puppet::Property) do
                @name = :alias
            end
            @shadow_class.initvars
        end

        it "should create an instance of the metaparameter at initialization" do
            Puppet::Type.metaparamclass(:alias).expects(:new).with(:resource => @resource)

            @shadow_class.new :resource => @resource
        end

        it "should munge values using the shadow's munge method" do
            shadow = mock 'shadow'
            Puppet::Type.metaparamclass(:alias).expects(:new).returns shadow

            shadow.expects(:munge).with "foo"

            property = @shadow_class.new :resource => @resource
            property.munge("foo")
        end
    end

    describe "when defining new values" do
        it "should define a method for each value created with a block that's not a regex" do
            @class.newvalue(:foo) { }
            @property.must respond_to(:set_foo)
        end
    end

    describe "when assigning the value" do
        it "should just set the 'should' value" do
            @property.value = "foo"
            @property.should.must == "foo"
        end

        it "should validate each value separately" do
            @property.expects(:validate).with("one")
            @property.expects(:validate).with("two")

            @property.value = %w{one two}
        end

        it "should munge each value separately and use any result as the actual value" do
            @property.expects(:munge).with("one").returns :one
            @property.expects(:munge).with("two").returns :two

            # Do this so we get the whole array back.
            @class.array_matching = :all

            @property.value = %w{one two}
            @property.should.must == [:one, :two]
        end

        it "should munge the canonicalization of the value" do
            @property.class.to_canonicalize { |x| x.reverse }
            @property.value = 'data'
            @property.should.must == 'atad'
        end

        it "should return any set value" do
            (@property.value = :one).should == :one
        end
    end

    describe "when returning the value" do
        it "should return nil if no value is set" do
            @property.should.must be_nil
        end

        it "should return the first set 'should' value if :array_matching is set to :first" do
            @class.array_matching = :first
            @property.should = %w{one two}
            @property.should.must == "one"
        end

        it "should return all set 'should' values as an array if :array_matching is set to :all" do
            @class.array_matching = :all
            @property.should = %w{one two}
            @property.should.must == %w{one two}
        end

        it "should default to :first array_matching" do
            @class.array_matching.should == :first
        end

        it "should unmunge the returned value if :array_matching is set to :first" do
            @property.class.unmunge do |v| v.to_sym end
            @class.array_matching = :first
            @property.should = %w{one two}

            @property.should.must == :one
        end

        it "should unmunge all the returned values if :array_matching is set to :all" do
            @property.class.unmunge do |v| v.to_sym end
            @class.array_matching = :all
            @property.should = %w{one two}

            @property.should.must == [:one, :two]
        end
    end

    describe "when validating values" do
        it "should do nothing if no values or regexes have been defined" do
            lambda { @property.should = "foo" }.should_not raise_error
        end

        it "should fail if the value is not a defined value or alias and does not match a regex" do
            @class.newvalue(:foo)

            lambda { @property.should = "bar" }.should raise_error
        end

        it "should succeeed if the value is one of the defined values" do
            @class.newvalue(:foo)

            lambda { @property.should = :foo }.should_not raise_error
        end

        it "should succeeed if the value is one of the defined values even if the definition uses a symbol and the validation uses a string" do
            @class.newvalue(:foo)

            lambda { @property.should = "foo" }.should_not raise_error
        end

        it "should succeeed if the value is one of the defined values even if the definition uses a string and the validation uses a symbol" do
            @class.newvalue("foo")

            lambda { @property.should = :foo }.should_not raise_error
        end

        it "should succeed if the value is one of the defined aliases" do
            @class.newvalue("foo")
            @class.aliasvalue("bar", "foo")

            lambda { @property.should = :bar }.should_not raise_error
        end

        it "should succeed if the value matches one of the regexes" do
            @class.newvalue(/./)

            lambda { @property.should = "bar" }.should_not raise_error
        end

        it "should validate that all required features are present" do
            @class.newvalue(:foo, :required_features => [:a, :b])

            @provider.expects(:satisfies?).with([:a, :b]).returns true

            @property.should = :foo
        end

        it "should fail if required features are missing" do
            @class.newvalue(:foo, :required_features => [:a, :b])

            @provider.expects(:satisfies?).with([:a, :b]).returns false

            lambda { @property.should = :foo }.should raise_error(Puppet::Error)
        end

        it "should internally raise an ArgumentError if required features are missing" do
            @class.newvalue(:foo, :required_features => [:a, :b])

            @provider.expects(:satisfies?).with([:a, :b]).returns false

            lambda { @property.validate_features_per_value :foo }.should raise_error(ArgumentError)
        end

        it "should validate that all required features are present for regexes" do
            value = @class.newvalue(/./, :required_features => [:a, :b])

            @provider.expects(:satisfies?).with([:a, :b]).returns true

            @property.should = "foo"
        end
    end

    describe "when munging values" do
        it "should do nothing if no values or regexes have been defined" do
            @property.munge("foo").should == "foo"
        end

        it "should return return any matching defined values" do
            @class.newvalue(:foo)
            @property.munge("foo").should == :foo
        end

        it "should return any matching aliases" do
            @class.newvalue(:foo)
            @class.aliasvalue(:bar, :foo)
            @property.munge("bar").should == :foo
        end

        it "should return the value if it matches a regex" do
            @class.newvalue(/./)
            @property.munge("bar").should == "bar"
        end

        it "should return the value if no other option is matched" do
            @class.newvalue(:foo)
            @property.munge("bar").should == "bar"
        end
    end

    describe "when syncing the 'should' value" do
        it "should set the value" do
            @class.newvalue(:foo)
            @property.should = :foo
            @property.expects(:set).with(:foo)
            @property.sync
        end
    end

    describe "when setting a value" do
        it "should catch exceptions and raise Puppet::Error" do
            @class.newvalue(:foo) { raise "eh" }
            lambda { @property.set(:foo) }.should raise_error(Puppet::Error)
        end

        describe "that was defined without a block" do
            it "should call the settor on the provider" do
                @class.newvalue(:bar)
                @provider.expects(:foo=).with :bar
                @property.set(:bar)
            end

            it "should return any specified event" do
                @class.newvalue(:bar, :event => :whatever)
                @property.should = :bar
                @provider.expects(:foo=).with :bar
                @property.set(:bar).should == :whatever
            end
        end

        describe "that was defined with a block" do
            it "should call the method created for the value if the value is not a regex" do
                @class.newvalue(:bar) {}
                @property.expects(:set_bar)
                @property.set(:bar)
            end

            it "should call the provided block if the value is a regex" do
                @class.newvalue(/./) { self.test }
                @property.expects(:test)
                @property.set("foo")
            end

            it "should return any specified event" do
                @class.newvalue(:bar, :event => :myevent) {}
                @property.expects(:set_bar)
                @property.set(:bar).should == :myevent
            end
        end
    end
end
