#!/usr/bin/env rspec
require 'spec_helper'

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

  it "should return its name as a string when converted to a string" do
    @parameter.to_s.should == @parameter.name.to_s
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
    @parameter.source_descriptors.should == {:tags=>["one", "two", "foo"], :path=>"//foo", :file => "file", :line => 10}
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

  describe "when logging" do
    it "should use its resource's log level and the provided message" do
      @resource.expects(:[]).with(:loglevel).returns :notice
      @parameter.expects(:send_log).with(:notice, "mymessage")
      @parameter.log "mymessage"
    end
  end
end
