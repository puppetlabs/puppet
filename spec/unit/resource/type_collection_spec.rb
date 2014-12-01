#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/resource/type_collection'
require 'puppet/resource/type'

describe Puppet::Resource::TypeCollection do
  include PuppetSpec::Files

  let(:environment) { Puppet::Node::Environment.create(:testing, []) }

  before do
    @instance = Puppet::Resource::Type.new(:hostclass, "foo")
    @code = Puppet::Resource::TypeCollection.new(environment)
  end

  it "should consider '<<' to be an alias to 'add' but should return self" do
    @code.expects(:add).with "foo"
    @code.expects(:add).with "bar"
    @code << "foo" << "bar"
  end

  it "should set itself as the code collection for added resource types" do
    node = Puppet::Resource::Type.new(:node, "foo")

    @code.add(node)
    @code.node("foo").should equal(node)

    node.resource_type_collection.should equal(@code)
  end

  it "should store node resource types as nodes" do
    node = Puppet::Resource::Type.new(:node, "foo")

    @code.add(node)
    @code.node("foo").should equal(node)
  end

  it "should fail if a duplicate node is added" do
    @code.add(Puppet::Resource::Type.new(:node, "foo"))

    expect do
      @code.add(Puppet::Resource::Type.new(:node, "foo"))
    end.to raise_error(Puppet::ParseError, /cannot redefine/)
  end

  it "should store hostclasses as hostclasses" do
    klass = Puppet::Resource::Type.new(:hostclass, "foo")

    @code.add(klass)
    @code.hostclass("foo").should equal(klass)
  end

  it "merge together hostclasses of the same name" do
    klass1 = Puppet::Resource::Type.new(:hostclass, "foo", :doc => "first")
    klass2 = Puppet::Resource::Type.new(:hostclass, "foo", :doc => "second")

    @code.add(klass1)
    @code.add(klass2)

    @code.hostclass("foo").doc.should == "firstsecond"
  end

  it "should store definitions as definitions" do
    define = Puppet::Resource::Type.new(:definition, "foo")

    @code.add(define)
    @code.definition("foo").should equal(define)
  end

  it "should fail if a duplicate definition is added" do
    @code.add(Puppet::Resource::Type.new(:definition, "foo"))

    expect do
      @code.add(Puppet::Resource::Type.new(:definition, "foo"))
    end.to raise_error(Puppet::ParseError, /cannot be redefined/)
  end

  it "should remove all nodes, classes, and definitions when cleared" do
    loader = Puppet::Resource::TypeCollection.new(environment)
    loader.add Puppet::Resource::Type.new(:hostclass, "class")
    loader.add Puppet::Resource::Type.new(:definition, "define")
    loader.add Puppet::Resource::Type.new(:node, "node")

    loader.clear
    loader.hostclass("class").should be_nil
    loader.definition("define").should be_nil
    loader.node("node").should be_nil
  end

  describe "when looking up names" do
    before do
      @type = Puppet::Resource::Type.new(:hostclass, "ns::klass")
    end

    it "should not attempt to import anything when the type is already defined" do
      @code.add @type
      @code.loader.expects(:import).never
      @code.find_hostclass("ns::klass").should equal(@type)
    end

    describe "that need to be loaded" do
      it "should use the loader to load the files" do
        @code.loader.expects(:try_load_fqname).with(:hostclass, "klass")
        @code.find_hostclass("klass")
      end
      it "should use the loader to load the files" do
        @code.loader.expects(:try_load_fqname).with(:hostclass, "ns::klass")
        @code.find_hostclass("ns::klass")
      end

      it "should downcase the name and downcase and array-fy the namespaces before passing to the loader" do
        @code.loader.expects(:try_load_fqname).with(:hostclass, "ns::klass")
        @code.find_hostclass("ns::klass")
      end

      it "should use the class returned by the loader" do
        @code.loader.expects(:try_load_fqname).returns(:klass)
        @code.expects(:hostclass).with("ns::klass").returns(false)
        @code.find_hostclass("ns::klass").should == :klass
      end

      it "should return nil if the name isn't found" do
        @code.loader.stubs(:try_load_fqname).returns(nil)
        @code.find_hostclass("Ns::Klass").should be_nil
      end

      it "already-loaded names at broader scopes should not shadow autoloaded names" do
        @code.add Puppet::Resource::Type.new(:hostclass, "bar")
        @code.loader.expects(:try_load_fqname).with(:hostclass, "foo::bar").returns(:foobar)
        @code.find_hostclass("foo::bar").should == :foobar
      end

      context 'when debugging' do
        # This test requires that debugging is on, it will otherwise not make a call to debug,
        # which is the easiest way to detect that that a certain path has been taken.
        before(:each) do
          Puppet.debug = true
        end

        after (:each) do
          Puppet.debug = false
        end

        it "should not try to autoload names that we couldn't autoload in a previous step if ignoremissingtypes is enabled" do
          Puppet[:ignoremissingtypes] = true
          @code.loader.expects(:try_load_fqname).with(:hostclass, "ns::klass").returns(nil)
          @code.find_hostclass("ns::klass").should be_nil
          Puppet.expects(:debug).at_least_once.with {|msg| msg =~ /Not attempting to load hostclass/}
          @code.find_hostclass("ns::klass").should be_nil
        end
      end
    end
  end

  %w{hostclass node definition}.each do |data|
    describe "behavior of add for #{data}" do

      it "should return the added #{data}" do
        loader = Puppet::Resource::TypeCollection.new(environment)
        instance = Puppet::Resource::Type.new(data, "foo")

        loader.add(instance).should equal(instance)
      end

      it "should retrieve #{data} insensitive to case" do
        loader = Puppet::Resource::TypeCollection.new(environment)
        instance = Puppet::Resource::Type.new(data, "Bar")

        loader.add instance

        loader.send(data, "bAr").should equal(instance)
      end

      it "should return nil when asked for a #{data} that has not been added" do
        Puppet::Resource::TypeCollection.new(environment).send(data, "foo").should be_nil
      end
    end
  end

  describe "when finding a qualified instance" do
    it "should return any found instance if the instance name is fully qualified" do
      loader = Puppet::Resource::TypeCollection.new(environment)
      instance = Puppet::Resource::Type.new(:hostclass, "foo::bar")
      loader.add instance
      loader.find_hostclass("::foo::bar").should equal(instance)
    end

    it "should return nil if the instance name is fully qualified and no such instance exists" do
      loader = Puppet::Resource::TypeCollection.new(environment)
      loader.find_hostclass("::foo::bar").should be_nil
    end

    it "should be able to find classes in the base namespace" do
      loader = Puppet::Resource::TypeCollection.new(environment)
      instance = Puppet::Resource::Type.new(:hostclass, "foo")
      loader.add instance
      loader.find_hostclass("foo").should equal(instance)
    end

    it "should return the unqualified object if it exists in a provided namespace" do
      loader = Puppet::Resource::TypeCollection.new(environment)
      instance = Puppet::Resource::Type.new(:hostclass, "foo::bar")
      loader.add instance
      loader.find_hostclass("foo::bar").should equal(instance)
    end

    it "should return nil if the object cannot be found" do
      loader = Puppet::Resource::TypeCollection.new(environment)
      instance = Puppet::Resource::Type.new(:hostclass, "foo::bar::baz")
      loader.add instance
      loader.find_hostclass("foo::bar::eh").should be_nil
    end

    describe "when topscope has a class that has the same name as a local class" do
      before do
        @loader = Puppet::Resource::TypeCollection.new(environment)
        [ "foo::bar", "bar" ].each do |name|
          @loader.add Puppet::Resource::Type.new(:hostclass, name)
        end
      end

      it "looks up the given name, no more, no less" do
        @loader.find_hostclass("bar").name.should == 'bar'
        @loader.find_hostclass("::bar").name.should == 'bar'
        @loader.find_hostclass("foo::bar").name.should == 'foo::bar'
        @loader.find_hostclass("::foo::bar").name.should == 'foo::bar'
      end
    end

    it "should not look in the local scope for classes when the name is qualified" do
        @loader = Puppet::Resource::TypeCollection.new(environment)
        @loader.add Puppet::Resource::Type.new(:hostclass, "foo::bar")

        @loader.find_hostclass("::bar").should == nil
    end

  end

  it "should be able to find nodes" do
    node = Puppet::Resource::Type.new(:node, "bar")
    loader = Puppet::Resource::TypeCollection.new(environment)
    loader.add(node)
    loader.find_node("bar").should == node
  end

  it "should indicate whether any nodes are defined" do
    loader = Puppet::Resource::TypeCollection.new(environment)
    loader.add_node(Puppet::Resource::Type.new(:node, "foo"))
    loader.should be_nodes
  end

  it "should indicate whether no nodes are defined" do
    Puppet::Resource::TypeCollection.new(environment).should_not be_nodes
  end

  describe "when finding nodes" do
    before :each do
      @loader = Puppet::Resource::TypeCollection.new(environment)
    end

    it "should return any node whose name exactly matches the provided node name" do
      node = Puppet::Resource::Type.new(:node, "foo")
      @loader << node

      @loader.node("foo").should equal(node)
    end

    it "should return the first regex node whose regex matches the provided node name" do
      node1 = Puppet::Resource::Type.new(:node, /\w/)
      node2 = Puppet::Resource::Type.new(:node, /\d/)
      @loader << node1 << node2

      @loader.node("foo10").should equal(node1)
    end

    it "should preferentially return a node whose name is string-equal over returning a node whose regex matches a provided name" do
      node1 = Puppet::Resource::Type.new(:node, /\w/)
      node2 = Puppet::Resource::Type.new(:node, "foo")
      @loader << node1 << node2

      @loader.node("foo").should equal(node2)
    end
  end

  describe "when determining the configuration version" do
    before do
      @code = Puppet::Resource::TypeCollection.new(environment)
    end

    it "should default to the current time" do
      time = Time.now

      Time.stubs(:now).returns time
      @code.version.should == time.to_i
    end

    context "when config_version script is specified" do
      let(:environment) { Puppet::Node::Environment.create(:testing, [], '', '/my/foo') }

      it "should use the output of the environment's config_version setting if one is provided" do
        Puppet::Util::Execution.expects(:execute).with(["/my/foo"]).returns "output\n"
        @code.version.should == "output"
      end

      it "should raise a puppet parser error if executing config_version fails" do
        Puppet::Util::Execution.expects(:execute).raises(Puppet::ExecutionFailure.new("msg"))

        lambda { @code.version }.should raise_error(Puppet::ParseError)
      end
    end
  end
end
