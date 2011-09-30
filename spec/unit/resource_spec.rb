#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/resource'

describe Puppet::Resource do
  include PuppetSpec::Files

  before do
    @basepath = make_absolute("/somepath")
  end

  [:catalog, :file, :line].each do |attr|
    it "should have an #{attr} attribute" do
      resource = Puppet::Resource.new("file", "/my/file")
      resource.should respond_to(attr)
      resource.should respond_to(attr.to_s + "=")
    end
  end

  it "should have a :title attribute" do
    Puppet::Resource.new(:user, "foo").title.should == "foo"
  end

  it "should require the type and title" do
    lambda { Puppet::Resource.new }.should raise_error(ArgumentError)
  end

  it "should canonize types to capitalized strings" do
    Puppet::Resource.new(:user, "foo").type.should == "User"
  end

  it "should canonize qualified types so all strings are capitalized" do
    Puppet::Resource.new("foo::bar", "foo").type.should == "Foo::Bar"
  end

  it "should tag itself with its type" do
    Puppet::Resource.new("file", "/f").should be_tagged("file")
  end

  it "should tag itself with its title if the title is a valid tag" do
    Puppet::Resource.new("user", "bar").should be_tagged("bar")
  end

  it "should not tag itself with its title if the title is a not valid tag" do
    Puppet::Resource.new("file", "/bar").should_not be_tagged("/bar")
  end

  it "should allow setting of attributes" do
    Puppet::Resource.new("file", "/bar", :file => "/foo").file.should == "/foo"
    Puppet::Resource.new("file", "/bar", :exported => true).should be_exported
  end

  it "should set its type to 'Class' and its title to the passed title if the passed type is :component and the title has no square brackets in it" do
    ref = Puppet::Resource.new(:component, "foo")
    ref.type.should == "Class"
    ref.title.should == "Foo"
  end

  it "should interpret the title as a reference and assign appropriately if the type is :component and the title contains square brackets" do
    ref = Puppet::Resource.new(:component, "foo::bar[yay]")
    ref.type.should == "Foo::Bar"
    ref.title.should == "yay"
  end

  it "should set the type to 'Class' if it is nil and the title contains no square brackets" do
    ref = Puppet::Resource.new(nil, "yay")
    ref.type.should == "Class"
    ref.title.should == "Yay"
  end

  it "should interpret the title as a reference and assign appropriately if the type is nil and the title contains square brackets" do
    ref = Puppet::Resource.new(nil, "foo::bar[yay]")
    ref.type.should == "Foo::Bar"
    ref.title.should == "yay"
  end

  it "should interpret the title as a reference and assign appropriately if the type is nil and the title contains nested square brackets" do
    ref = Puppet::Resource.new(nil, "foo::bar[baz[yay]]")
    ref.type.should == "Foo::Bar"
    ref.title.should =="baz[yay]"
  end

  it "should interpret the type as a reference and assign appropriately if the title is nil and the type contains square brackets" do
    ref = Puppet::Resource.new("foo::bar[baz]")
    ref.type.should == "Foo::Bar"
    ref.title.should =="baz"
  end

  it "should be able to extract its information from a Puppet::Type instance" do
    ral = Puppet::Type.type(:file).new :path => @basepath+"/foo"
    ref = Puppet::Resource.new(ral)
    ref.type.should == "File"
    ref.title.should == @basepath+"/foo"
  end


  it "should fail if the title is nil and the type is not a valid resource reference string" do
    lambda { Puppet::Resource.new("foo") }.should raise_error(ArgumentError)
  end

  it 'should fail if strict is set and type does not exist' do
    lambda { Puppet::Resource.new('foo', 'title', {:strict=>true}) }.should raise_error(ArgumentError, 'Invalid resource type foo')
  end

  it 'should fail if strict is set and class does not exist' do
    lambda { Puppet::Resource.new('Class', 'foo', {:strict=>true}) }.should raise_error(ArgumentError, 'Could not find declared class foo')
  end

  it "should fail if the title is a hash and the type is not a valid resource reference string" do
    expect { Puppet::Resource.new({:type => "foo", :title => "bar"}) }.
      to raise_error ArgumentError, /Puppet::Resource.new does not take a hash/
  end

  it "should be able to produce a backward-compatible reference array" do
    Puppet::Resource.new("foobar", "/f").to_trans_ref.should == %w{Foobar /f}
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

  it "should support an environment attribute" do
    Puppet::Resource.new("file", "/my/file", :environment => :foo).environment.name.should == :foo
  end

  describe "and munging its type and title" do
    describe "when modeling a builtin resource" do
      it "should be able to find the resource type" do
        Puppet::Resource.new("file", "/my/file").resource_type.should equal(Puppet::Type.type(:file))
      end

      it "should set its type to the capitalized type name" do
        Puppet::Resource.new("file", "/my/file").type.should == "File"
      end
    end

    describe "when modeling a defined resource" do
      describe "that exists" do
        before do
          @type = Puppet::Resource::Type.new(:definition, "foo::bar")
          Puppet::Node::Environment.new.known_resource_types.add @type
        end

        it "should set its type to the capitalized type name" do
          Puppet::Resource.new("foo::bar", "/my/file").type.should == "Foo::Bar"
        end

        it "should be able to find the resource type" do
          Puppet::Resource.new("foo::bar", "/my/file").resource_type.should equal(@type)
        end

        it "should set its title to the provided title" do
          Puppet::Resource.new("foo::bar", "/my/file").title.should == "/my/file"
        end
      end

      describe "that does not exist" do
        it "should set its resource type to the capitalized resource type name" do
          Puppet::Resource.new("foo::bar", "/my/file").type.should == "Foo::Bar"
        end
      end
    end

    describe "when modeling a node" do
      # Life's easier with nodes, because they can't be qualified.
      it "should set its type to 'Node' and its title to the provided title" do
        node = Puppet::Resource.new("node", "foo")
        node.type.should == "Node"
        node.title.should == "foo"
      end
    end

    describe "when modeling a class" do
      it "should set its type to 'Class'" do
        Puppet::Resource.new("class", "foo").type.should == "Class"
      end

      describe "that exists" do
        before do
          @type = Puppet::Resource::Type.new(:hostclass, "foo::bar")
          Puppet::Node::Environment.new.known_resource_types.add @type
        end

        it "should set its title to the capitalized, fully qualified resource type" do
          Puppet::Resource.new("class", "foo::bar").title.should == "Foo::Bar"
        end

        it "should be able to find the resource type" do
          Puppet::Resource.new("class", "foo::bar").resource_type.should equal(@type)
        end
      end

      describe "that does not exist" do
        it "should set its type to 'Class' and its title to the capitalized provided name" do
          klass = Puppet::Resource.new("class", "foo::bar")
          klass.type.should == "Class"
          klass.title.should == "Foo::Bar"
        end
      end

      describe "and its name is set to the empty string" do
        it "should set its title to :main" do
          Puppet::Resource.new("class", "").title.should == :main
        end

        describe "and a class exists whose name is the empty string" do # this was a bit tough to track down
          it "should set its title to :main" do
            @type = Puppet::Resource::Type.new(:hostclass, "")
            Puppet::Node::Environment.new.known_resource_types.add @type

            Puppet::Resource.new("class", "").title.should == :main
          end
        end
      end

      describe "and its name is set to :main" do
        it "should set its title to :main" do
          Puppet::Resource.new("class", :main).title.should == :main
        end

        describe "and a class exists whose name is the empty string" do # this was a bit tough to track down
          it "should set its title to :main" do
            @type = Puppet::Resource::Type.new(:hostclass, "")
            Puppet::Node::Environment.new.known_resource_types.add @type

            Puppet::Resource.new("class", :main).title.should == :main
          end
        end
      end
    end
  end

  it "should return nil when looking up resource types that don't exist" do
    Puppet::Resource.new("foobar", "bar").resource_type.should be_nil
  end

  it "should not fail when an invalid parameter is used and strict mode is disabled" do
    type = Puppet::Resource::Type.new(:definition, "foobar")
    Puppet::Node::Environment.new.known_resource_types.add type
    resource = Puppet::Resource.new("foobar", "/my/file")
    resource[:yay] = true
  end

  it "should be considered equivalent to another resource if their type and title match and no parameters are set" do
    Puppet::Resource.new("file", "/f").should == Puppet::Resource.new("file", "/f")
  end

  it "should be considered equivalent to another resource if their type, title, and parameters are equal" do
    Puppet::Resource.new("file", "/f", :parameters => {:foo => "bar"}).should == Puppet::Resource.new("file", "/f", :parameters => {:foo => "bar"})
  end

  it "should not be considered equivalent to another resource if their type and title match but parameters are different" do
    Puppet::Resource.new("file", "/f", :parameters => {:fee => "baz"}).should_not == Puppet::Resource.new("file", "/f", :parameters => {:foo => "bar"})
  end

  it "should not be considered equivalent to a non-resource" do
    Puppet::Resource.new("file", "/f").should_not == "foo"
  end

  it "should not be considered equivalent to another resource if their types do not match" do
    Puppet::Resource.new("file", "/f").should_not == Puppet::Resource.new("exec", "/f")
  end

  it "should not be considered equivalent to another resource if their titles do not match" do
    Puppet::Resource.new("file", "/foo").should_not == Puppet::Resource.new("file", "/f")
  end

  describe "when referring to a resource with name canonicalization" do
    it "should canonicalize its own name" do
      res = Puppet::Resource.new("file", "/path/")
      res.uniqueness_key.should == ["/path"]
      res.ref.should == "File[/path/]"
    end
  end

  describe "when running in strict mode" do
    it "should be strict" do
      Puppet::Resource.new("file", "/path", :strict => true).should be_strict
    end

    it "should fail if invalid parameters are used" do
      lambda { Puppet::Resource.new("file", "/path", :strict => true, :parameters => {:nosuchparam => "bar"}) }.should raise_error
    end

    it "should fail if the resource type cannot be resolved" do
      lambda { Puppet::Resource.new("nosuchtype", "/path", :strict => true) }.should raise_error
    end
  end

  describe "when managing parameters" do
    before do
      @resource = Puppet::Resource.new("file", "/my/file")
    end

    it "should correctly detect when provided parameters are not valid for builtin types" do
      Puppet::Resource.new("file", "/my/file").should_not be_valid_parameter("foobar")
    end

    it "should correctly detect when provided parameters are valid for builtin types" do
      Puppet::Resource.new("file", "/my/file").should be_valid_parameter("mode")
    end

    it "should correctly detect when provided parameters are not valid for defined resource types" do
      type = Puppet::Resource::Type.new(:definition, "foobar")
      Puppet::Node::Environment.new.known_resource_types.add type
      Puppet::Resource.new("foobar", "/my/file").should_not be_valid_parameter("myparam")
    end

    it "should correctly detect when provided parameters are valid for defined resource types" do
      type = Puppet::Resource::Type.new(:definition, "foobar", :arguments => {"myparam" => nil})
      Puppet::Node::Environment.new.known_resource_types.add type
      Puppet::Resource.new("foobar", "/my/file").should be_valid_parameter("myparam")
    end

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
      resource = Puppet::Resource.new("user", "bob")
      Puppet::Type.type(:user).stubs(:key_attributes).returns [:myvar]
      resource[:name] = "bob"
      resource[:myvar].should == "bob"
    end

    it "should return the namevar when asked to return the name" do
      resource = Puppet::Resource.new("user", "bob")
      Puppet::Type.type(:user).stubs(:key_attributes).returns [:myvar]
      resource[:myvar] = "test"
      resource[:name].should == "test"
    end

    it "should be able to set the name for non-builtin types" do
      resource = Puppet::Resource.new(:foo, "bar")
      resource[:name] = "eh"
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
      resource = Puppet::Resource.new("user", "bob")
      Puppet::Type.type(:user).stubs(:key_attributes).returns [:myvar]
      resource.to_hash[:myvar].should == "bob"
    end

    it "should set :name to the title if :name is not present for non-builtin types" do
      krt = Puppet::Resource::TypeCollection.new("myenv")
      krt.add Puppet::Resource::Type.new(:definition, :foo)
      resource = Puppet::Resource.new :foo, "bar"
      resource.stubs(:known_resource_types).returns krt
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

  describe "when loading 0.25.x storedconfigs YAML" do
    before :each do
      @old_storedconfig_yaml = %q{--- !ruby/object:Puppet::Resource::Reference
builtin_type:
title: /tmp/bar
type: File
}
    end

    it "should deserialize a Puppet::Resource::Reference without exceptions" do
      lambda { YAML.load(@old_storedconfig_yaml) }.should_not raise_error
    end

    it "should deserialize as a Puppet::Resource::Reference as a Puppet::Resource" do
      YAML.load(@old_storedconfig_yaml).class.should == Puppet::Resource
    end

    it "should to_hash properly" do
      YAML.load(@old_storedconfig_yaml).to_hash.should == { :path => "/tmp/bar" }
    end
  end

  describe "when converting to a RAL resource" do
    it "should use the resource type's :new method to create the resource if the resource is of a builtin type" do
      resource = Puppet::Resource.new("file", @basepath+"/my/file")
      result = resource.to_ral
      result.should be_instance_of(Puppet::Type.type(:file))
      result[:path].should == @basepath+"/my/file"
    end

    it "should convert to a component instance if the resource type is not of a builtin type" do
      resource = Puppet::Resource.new("foobar", "somename")
      result = resource.to_ral

      result.should be_instance_of(Puppet::Type.type(:component))
      result.title.should == "Foobar[somename]"
    end
  end

  describe "when converting to puppet code" do
    before do
      @resource = Puppet::Resource.new("one::two", "/my/file",
        :parameters => {
          :noop => true,
          :foo => %w{one two},
          :ensure => 'present',
        }
      )
    end

    it "should align, sort and add trailing commas to attributes with ensure first", :'fails_on_ruby_1.9.2' => true do
      @resource.to_manifest.should == <<-HEREDOC.gsub(/^\s{8}/, '').gsub(/\n$/, '')
        one::two { '/my/file':
          ensure => 'present',
          foo    => ['one', 'two'],
          noop   => 'true',
        }
      HEREDOC
    end
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

      it "should return a simple TransBucket if it is a stage" do
        @resource = Puppet::Resource.new("stage", "bar")
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
        @resource[:foo] = Puppet::Resource.new(:file, "/f")
        @resource.to_trans["foo"].should == %w{File /f}
      end

      it "should convert resource references into the backward-compatible form even when within arrays" do
        @resource[:foo] = ["a", Puppet::Resource.new(:file, "/f")]
        @resource.to_trans["foo"].should == ["a", %w{File /f}]
      end
    end
  end

  describe "when converting to pson", :if => Puppet.features.pson? do
    def pson_output_should
      @resource.class.expects(:pson_create).with { |hash| yield hash }
    end

    it "should include the pson util module" do
      Puppet::Resource.singleton_class.ancestors.should be_include(Puppet::Util::Pson)
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

    it "should serialize relationships as reference strings" do
      resource = Puppet::Resource.new("File", "/foo")
      resource[:requires] = Puppet::Resource.new("File", "/bar")
      result = Puppet::Resource.from_pson(PSON.parse(resource.to_pson))
      result[:requires].should == "File[/bar]"
    end

    it "should serialize multiple relationships as arrays of reference strings" do
      resource = Puppet::Resource.new("File", "/foo")
      resource[:requires] = [Puppet::Resource.new("File", "/bar"), Puppet::Resource.new("File", "/baz")]
      result = Puppet::Resource.from_pson(PSON.parse(resource.to_pson))
      result[:requires].should == [ "File[/bar]",  "File[/baz]" ]
    end
  end

  describe "when converting from pson", :if => Puppet.features.pson? do
    def pson_result_should
      Puppet::Resource.expects(:new).with { |hash| yield hash }
    end

    before do
      @data = {
        'type' => "file",
        'title' => @basepath+"/yay",
      }
    end

    it "should set its type to the provided type" do
      Puppet::Resource.from_pson(@data).type.should == "File"
    end

    it "should set its title to the provided title" do
      Puppet::Resource.from_pson(@data).title.should == @basepath+"/yay"
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
      Puppet::Resource.indirection.terminus_class.should be
    end

    it "should have a name" do
      Puppet::Resource.new("file", "/my/file").name.should == "File//my/file"
    end
  end

  describe "when resolving resources with a catalog" do
    it "should resolve all resources using the catalog" do
      catalog = mock 'catalog'
      resource = Puppet::Resource.new("foo::bar", "yay")
      resource.catalog = catalog

      catalog.expects(:resource).with("Foo::Bar[yay]").returns(:myresource)

      resource.resolve.should == :myresource
    end
  end

  describe "when generating the uniqueness key" do
    it "should include all of the key_attributes in alphabetical order by attribute name" do
      Puppet::Type.type(:file).stubs(:key_attributes).returns [:myvar, :owner, :path]
      Puppet::Type.type(:file).stubs(:title_patterns).returns(
        [ [ /(.*)/, [ [:path, lambda{|x| x} ] ] ] ]
      )
      res = Puppet::Resource.new("file", "/my/file", :parameters => {:owner => 'root', :content => 'hello'})
      res.uniqueness_key.should == [ nil, 'root', '/my/file']
    end
  end

  describe "#prune_parameters" do
    before do
      Puppet.newtype('blond') do
        newproperty(:ensure)
        newproperty(:height)
        newproperty(:weight)
        newproperty(:sign)
        newproperty(:friends)
        newparam(:admits_to_dying_hair)
        newparam(:admits_to_age)
        newparam(:name)
      end
    end

    it "should strip all parameters and strip properties that are nil, empty or absent except for ensure" do
      resource = Puppet::Resource.new("blond", "Bambi", :parameters => {
        :ensure               => 'absent',
        :height               => '',
        :weight               => 'absent',
        :friends              => [],
        :admits_to_age        => true,
        :admits_to_dying_hair => false
      })

      pruned_resource = resource.prune_parameters
      pruned_resource.should == Puppet::Resource.new("blond", "Bambi", :parameters => {:ensure => 'absent'})
    end

    it "should leave parameters alone if in parameters_to_include" do
      resource = Puppet::Resource.new("blond", "Bambi", :parameters => {
        :admits_to_age        => true,
        :admits_to_dying_hair => false
      })

      pruned_resource = resource.prune_parameters(:parameters_to_include => [:admits_to_dying_hair])
      pruned_resource.should == Puppet::Resource.new("blond", "Bambi", :parameters => {:admits_to_dying_hair => false})
    end

    it "should leave properties if not nil, absent or empty" do
      resource = Puppet::Resource.new("blond", "Bambi", :parameters => {
        :ensure          => 'silly',
        :height          => '7 ft 5 in',
        :friends         => ['Oprah'],
      })

      pruned_resource = resource.prune_parameters
      pruned_resource.should ==
      resource = Puppet::Resource.new("blond", "Bambi", :parameters => {
        :ensure          => 'silly',
        :height          => '7 ft 5 in',
        :friends         => ['Oprah'],
      })
    end
  end
end
