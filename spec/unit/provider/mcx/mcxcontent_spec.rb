#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:mcx).provider(:mcxcontent)

# describe creates a new ExampleGroup object.
describe provider_class do

  # :each executes before each test.
  # :all executes once for the test group and before :each.
  before :each do
    # Create a mock resource
    @resource = stub 'resource'

    @provider = provider_class.new
    @attached_to = "/Users/foobar"
    @ds_path = "/Local/Default/Users/foobar"

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name, ensure and enable
    @resource.stubs(:[]).with(:name).returns @attached_to
    @resource.stubs(:[]).with(:ensure).returns :present
    @resource.stubs(:ref).returns "Mcx[#{@attached_to}]"

    # stub out the provider methods that actually touch the filesystem
    # or execute commands
    @provider.class.stubs(:execute).returns('')
    @provider.stubs(:execute).returns('')
    @provider.stubs(:resource).returns @resource
  end

  it "should have a create method." do
    @provider.should respond_to(:create)
  end

  it "should have a destroy method." do
    @provider.should respond_to(:destroy)
  end

  it "should have an exists? method." do
    @provider.should respond_to(:exists?)
  end

  it "should have an content method." do
    @provider.should respond_to(:content)
  end

  it "should have an content= method." do
    @provider.should respond_to(:content=)
  end

  describe "when managing the resource" do
    it "should execute external command dscl from :create" do
      @provider.class.expects(:dscl).returns('').once
      @provider.create
    end
    it "should execute external command dscl from :destroy" do
      @provider.class.expects(:dscl).with('localhost', '-mcxdelete', @ds_path).returns('').once
      @provider.destroy
    end
    it "should execute external command dscl from :exists?" do
      @provider.class.expects(:dscl).with('localhost', '-mcxexport', @ds_path).returns('').once
      @provider.exists?
    end
    it "should execute external command dscl from :content" do
      @provider.class.expects(:dscl).with('localhost', '-mcxexport', @ds_path).returns('')
      @provider.content
    end
    it "should execute external command dscl from :content=" do
      @provider.class.expects(:dscl).returns('')
      @provider.content=''
    end
  end

  describe "when creating and parsing the name for ds_type" do
    before :each do
      @resource.stubs(:[]).with(:name).returns "/Foo/bar"
    end
    it "should not accept /Foo/bar" do
      lambda { @provider.create }.should raise_error(MCXContentProviderException)
    end
    it "should accept /Foo/bar with ds_type => user" do
      @resource.stubs(:[]).with(:ds_type).returns "user"
      lambda { @provider.create }.should_not raise_error(MCXContentProviderException)
    end
    it "should accept /Foo/bar with ds_type => group" do
      @resource.stubs(:[]).with(:ds_type).returns "group"
      lambda { @provider.create }.should_not raise_error(MCXContentProviderException)
    end
    it "should accept /Foo/bar with ds_type => computer" do
      @resource.stubs(:[]).with(:ds_type).returns "computer"
      lambda { @provider.create }.should_not raise_error(MCXContentProviderException)
    end
    it "should accept :name => /Foo/bar with ds_type => computerlist" do
      @resource.stubs(:[]).with(:ds_type).returns "computerlist"
      lambda { @provider.create }.should_not raise_error(MCXContentProviderException)
    end
  end

  describe "when creating and :name => foobar" do
    before :each do
      @resource.stubs(:[]).with(:name).returns "foobar"
    end
    it "should not accept unspecified :ds_type and :ds_name" do
      lambda { @provider.create }.should raise_error(MCXContentProviderException)
    end
    it "should not accept unspecified :ds_type" do
      @resource.stubs(:[]).with(:ds_type).returns "user"
      lambda { @provider.create }.should raise_error(MCXContentProviderException)
    end
    it "should not accept unspecified :ds_name" do
      @resource.stubs(:[]).with(:ds_name).returns "foo"
      lambda { @provider.create }.should raise_error(MCXContentProviderException)
    end
    it "should accept :ds_type => user, ds_name => foo" do
      @resource.stubs(:[]).with(:ds_type).returns "user"
      @resource.stubs(:[]).with(:ds_name).returns "foo"
      lambda { @provider.create }.should_not raise_error(MCXContentProviderException)
    end
    it "should accept :ds_type => group, ds_name => foo" do
      @resource.stubs(:[]).with(:ds_type).returns "group"
      @resource.stubs(:[]).with(:ds_name).returns "foo"
      lambda { @provider.create }.should_not raise_error(MCXContentProviderException)
    end
    it "should accept :ds_type => computer, ds_name => foo" do
      @resource.stubs(:[]).with(:ds_type).returns "computer"
      @resource.stubs(:[]).with(:ds_name).returns "foo"
      lambda { @provider.create }.should_not raise_error(MCXContentProviderException)
    end
    it "should accept :ds_type => computerlist, ds_name => foo" do
      @resource.stubs(:[]).with(:ds_type).returns "computerlist"
      @resource.stubs(:[]).with(:ds_name).returns "foo"
      lambda { @provider.create }.should_not raise_error(MCXContentProviderException)
    end
    it "should not accept :ds_type => bogustype, ds_name => foo" do
      @resource.stubs(:[]).with(:ds_type).returns "bogustype"
      @resource.stubs(:[]).with(:ds_name).returns "foo"
      lambda { @provider.create }.should raise_error(MCXContentProviderException)
    end
  end

  describe "when gathering existing instances" do
    it "should define an instances class method." do
      @provider.class.should respond_to(:instances)
    end
    it "should call external command dscl -list /Local/Default/<ds_type> on each known ds_type" do
      @provider.class.expects(:dscl).with('localhost', '-list', "/Local/Default/Users").returns('')
      @provider.class.expects(:dscl).with('localhost', '-list', "/Local/Default/Groups").returns('')
      @provider.class.expects(:dscl).with('localhost', '-list', "/Local/Default/Computers").returns('')
      @provider.class.expects(:dscl).with('localhost', '-list', "/Local/Default/ComputerLists").returns('')
      @provider.class.instances
    end
  end
end
