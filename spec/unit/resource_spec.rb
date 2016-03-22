#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/resource'

describe Puppet::Resource do
  include PuppetSpec::Files

  let(:basepath) { make_absolute("/somepath") }
  let(:environment) { Puppet::Node::Environment.create(:testing, []) }

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
    expect { Puppet::Resource.new }.to raise_error(ArgumentError)
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

  it "should not interpret the title as a reference if the type is a non component or whit reference" do
    ref = Puppet::Resource.new("Notify", "foo::bar[baz]")
    ref.type.should == "Notify"
    ref.title.should =="foo::bar[baz]"
  end

  it "should be able to extract its information from a Puppet::Type instance" do
    ral = Puppet::Type.type(:file).new :path => basepath+"/foo"
    ref = Puppet::Resource.new(ral)
    ref.type.should == "File"
    ref.title.should == basepath+"/foo"
  end


  it "should fail if the title is nil and the type is not a valid resource reference string" do
    expect { Puppet::Resource.new("resource-spec-foo") }.to raise_error(ArgumentError)
  end

  it 'should fail if strict is set and type does not exist' do
    expect { Puppet::Resource.new('resource-spec-foo', 'title', {:strict=>true}) }.to raise_error(ArgumentError, 'Invalid resource type resource-spec-foo')
  end

  it 'should fail if strict is set and class does not exist' do
    expect { Puppet::Resource.new('Class', 'resource-spec-foo', {:strict=>true}) }.to raise_error(ArgumentError, 'Could not find declared class resource-spec-foo')
  end

  it "should fail if the title is a hash and the type is not a valid resource reference string" do
    expect { Puppet::Resource.new({:type => "resource-spec-foo", :title => "bar"}) }.
      to raise_error ArgumentError, /Puppet::Resource.new does not take a hash/
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
          environment.known_resource_types.add @type
        end

        it "should set its type to the capitalized type name" do
          Puppet::Resource.new("foo::bar", "/my/file", :environment => environment).type.should == "Foo::Bar"
        end

        it "should be able to find the resource type" do
          Puppet::Resource.new("foo::bar", "/my/file", :environment => environment).resource_type.should equal(@type)
        end

        it "should set its title to the provided title" do
          Puppet::Resource.new("foo::bar", "/my/file", :environment => environment).title.should == "/my/file"
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
          environment.known_resource_types.add @type
        end

        it "should set its title to the capitalized, fully qualified resource type" do
          Puppet::Resource.new("class", "foo::bar", :environment => environment).title.should == "Foo::Bar"
        end

        it "should be able to find the resource type" do
          Puppet::Resource.new("class", "foo::bar", :environment => environment).resource_type.should equal(@type)
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
            environment.known_resource_types.add @type

            Puppet::Resource.new("class", "", :environment => environment).title.should == :main
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
            environment.known_resource_types.add @type

            Puppet::Resource.new("class", :main, :environment => environment).title.should == :main
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
    environment.known_resource_types.add type
    resource = Puppet::Resource.new("foobar", "/my/file", :environment => environment)
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

  describe "when setting default parameters" do
    let(:foo_node) { Puppet::Node.new('foo', :environment => environment) }
    let(:compiler) { Puppet::Parser::Compiler.new(foo_node) }
    let(:scope)    { Puppet::Parser::Scope.new(compiler) }

    def ast_string(value)
      Puppet::Parser::AST::String.new({:value => value})
    end

    it "should fail when asked to set default values and it is not a parser resource" do
      environment.known_resource_types.add(
      Puppet::Resource::Type.new(:definition, "default_param", :arguments => {"a" => ast_string("default")})
      )
      resource = Puppet::Resource.new("default_param", "name", :environment => environment)
      lambda { resource.set_default_parameters(scope) }.should raise_error(Puppet::DevError)
    end

    it "should evaluate and set any default values when no value is provided" do
      environment.known_resource_types.add(
        Puppet::Resource::Type.new(:definition, "default_param", :arguments => {"a" => ast_string("a_default_value")})
      )
      resource = Puppet::Parser::Resource.new("default_param", "name", :scope => scope)
      resource.set_default_parameters(scope)
      resource["a"].should == "a_default_value"
    end

    it "should skip attributes with no default value" do
      environment.known_resource_types.add(
        Puppet::Resource::Type.new(:definition, "no_default_param", :arguments => {"a" => ast_string("a_default_value")})
      )
      resource = Puppet::Parser::Resource.new("no_default_param", "name", :scope => scope)
      lambda { resource.set_default_parameters(scope) }.should_not raise_error
    end

    it "should return the list of default parameters set" do
      environment.known_resource_types.add(
        Puppet::Resource::Type.new(:definition, "default_param", :arguments => {"a" => ast_string("a_default_value")})
      )
      resource = Puppet::Parser::Resource.new("default_param", "name", :scope => scope)
      resource.set_default_parameters(scope).should == ["a"]
    end

    describe "when the resource type is :hostclass" do
      let(:environment_name) { "testing env" }
      let(:fact_values) { { :a => 1 } }
      let(:port) { Puppet::Parser::AST::String.new(:value => '80') }
      let(:apache) { Puppet::Resource::Type.new(:hostclass, 'apache', :arguments => { 'port' => port }) }

      before do
        environment.known_resource_types.add(apache)

        scope.stubs(:host).returns('host')
        scope.stubs(:environment).returns(environment)
        scope.stubs(:facts).returns(Puppet::Node::Facts.new("facts", fact_values))
      end

      context "when no value is provided" do
        before(:each) do
          Puppet[:binder] = true
        end

        let(:resource) do
          Puppet::Parser::Resource.new("class", "apache", :scope => scope)
        end

        it "should query the data_binding terminus using a namespaced key" do
          Puppet::DataBinding.indirection.expects(:find).with(
            'apache::port', all_of(has_key(:environment), has_key(:variables)))
          resource.set_default_parameters(scope)
        end

        it "should use the value from the data_binding terminus" do
          Puppet::DataBinding.indirection.expects(:find).returns('443')

          resource.set_default_parameters(scope)

          resource[:port].should == '443'
        end

        it "should use the default value if the data_binding terminus returns nil" do
          Puppet::DataBinding.indirection.expects(:find).returns(nil)

          resource.set_default_parameters(scope)

          resource[:port].should == '80'
        end

        it "should fail with error message about data binding on a hiera failure" do
          Puppet::DataBinding.indirection.expects(:find).raises(Puppet::DataBinding::LookupError, 'Forgettabotit')
          expect {
            resource.set_default_parameters(scope)
          }.to raise_error(Puppet::Error, /Error from DataBinding 'hiera' while looking up 'apache::port':.*Forgettabotit/)
        end

      end

      context "when a value is provided" do
        let(:port_parameter) do
          Puppet::Parser::Resource::Param.new(
            { :name => 'port', :value => '8080' }
          )
        end

        let(:resource) do
          Puppet::Parser::Resource.new("class", "apache", :scope => scope,
            :parameters => [port_parameter])
        end

        it "should not query the data_binding terminus" do
          Puppet::DataBinding.indirection.expects(:find).never
          resource.set_default_parameters(scope)
        end

        it "should not query the injector" do
          # enable the injector
          Puppet[:binder] = true
          compiler.injector.expects(:find).never
          resource.set_default_parameters(scope)
        end

        it "should use the value provided" do
          Puppet::DataBinding.indirection.expects(:find).never
          resource.set_default_parameters(scope).should == []
          resource[:port].should == '8080'
        end
      end
    end
  end

  describe "when validating all required parameters are present" do
    it "should be able to validate that all required parameters are present" do
      environment.known_resource_types.add(
        Puppet::Resource::Type.new(:definition, "required_param", :arguments => {"a" => nil})
      )
      lambda { Puppet::Resource.new("required_param", "name", :environment => environment).validate_complete }.should raise_error(Puppet::ParseError)
    end

    it "should not fail when all required parameters are present" do
      environment.known_resource_types.add(
        Puppet::Resource::Type.new(:definition, "no_required_param")
      )
      resource = Puppet::Resource.new("no_required_param", "name", :environment => environment)
      resource["a"] = "meh"
      lambda { resource.validate_complete }.should_not raise_error
    end

    it "should not validate against builtin types" do
      lambda { Puppet::Resource.new("file", "/bar").validate_complete }.should_not raise_error
    end
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
      expect { Puppet::Resource.new("file", "/path", :strict => true, :parameters => {:nosuchparam => "bar"}) }.to raise_error
    end

    it "should fail if the resource type cannot be resolved" do
      expect { Puppet::Resource.new("nosuchtype", "/path", :strict => true) }.to raise_error
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
      environment.known_resource_types.add type
      Puppet::Resource.new("foobar", "/my/file", :environment => environment).should_not be_valid_parameter("myparam")
    end

    it "should correctly detect when provided parameters are valid for defined resource types" do
      type = Puppet::Resource::Type.new(:definition, "foobar", :arguments => {"myparam" => nil})
      environment.known_resource_types.add type
      Puppet::Resource.new("foobar", "/my/file", :environment => environment).should be_valid_parameter("myparam")
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
      expect { resource[:name] = "eh" }.to_not raise_error
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

  describe "when serializing a native type" do
    before do
      @resource = Puppet::Resource.new("file", "/my/file")
      @resource["one"] = "test"
      @resource["two"] = "other"
    end

    it "should produce an equivalent yaml object" do
      text = @resource.render('yaml')

      newresource = Puppet::Resource.convert_from('yaml', text)
      newresource.should equal_resource_attributes_of @resource
    end
  end

  describe "when serializing a defined type" do
    before do
      type = Puppet::Resource::Type.new(:definition, "foo::bar")
      environment.known_resource_types.add type

      @resource = Puppet::Resource.new('foo::bar', 'xyzzy', :environment => environment)
      @resource['one'] = 'test'
      @resource['two'] = 'other'
      @resource.resource_type
    end

    it "doesn't include transient instance variables (#4506)" do
      expect(@resource.to_yaml_properties).to_not include :@rstype
    end

    it "produces an equivalent yaml object" do
      text = @resource.render('yaml')

      newresource = Puppet::Resource.convert_from('yaml', text)
      newresource.should equal_resource_attributes_of @resource
    end
  end

  describe "when converting to a RAL resource" do
    it "should use the resource type's :new method to create the resource if the resource is of a builtin type" do
      resource = Puppet::Resource.new("file", basepath+"/my/file")
      result = resource.to_ral
      result.must be_instance_of(Puppet::Type.type(:file))
      result[:path].should == basepath+"/my/file"
    end

    it "should convert to a component instance if the resource type is not of a builtin type" do
      resource = Puppet::Resource.new("foobar", "somename")
      result = resource.to_ral

      result.must be_instance_of(Puppet::Type.type(:component))
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

    it "should align, sort and add trailing commas to attributes with ensure first" do
      @resource.to_manifest.should == <<-HEREDOC.gsub(/^\s{8}/, '').gsub(/\n$/, '')
        one::two { '/my/file':
          ensure => 'present',
          foo    => ['one', 'two'],
          noop   => 'true',
        }
      HEREDOC
    end
  end

  describe "when converting to pson" do
    def pson_output_should
      @resource.class.expects(:pson_create).with { |hash| yield hash }
    end

    it "should include the pson util module" do
      Puppet::Resource.singleton_class.ancestors.should be_include(Puppet::Util::Pson)
    end

    # LAK:NOTE For all of these tests, we convert back to the resource so we can
    # trap the actual data structure then.

    it "should set its type to the provided type" do
      Puppet::Resource.from_data_hash(PSON.parse(Puppet::Resource.new("File", "/foo").to_pson)).type.should == "File"
    end

    it "should set its title to the provided title" do
      Puppet::Resource.from_data_hash(PSON.parse(Puppet::Resource.new("File", "/foo").to_pson)).title.should == "/foo"
    end

    it "should include all tags from the resource" do
      resource = Puppet::Resource.new("File", "/foo")
      resource.tag("yay")

      Puppet::Resource.from_data_hash(PSON.parse(resource.to_pson)).tags.should == resource.tags
    end

    it "should include the file if one is set" do
      resource = Puppet::Resource.new("File", "/foo")
      resource.file = "/my/file"

      Puppet::Resource.from_data_hash(PSON.parse(resource.to_pson)).file.should == "/my/file"
    end

    it "should include the line if one is set" do
      resource = Puppet::Resource.new("File", "/foo")
      resource.line = 50

      Puppet::Resource.from_data_hash(PSON.parse(resource.to_pson)).line.should == 50
    end

    it "should include the 'exported' value if one is set" do
      resource = Puppet::Resource.new("File", "/foo")
      resource.exported = true

      Puppet::Resource.from_data_hash(PSON.parse(resource.to_pson)).exported?.should be_true
    end

    it "should set 'exported' to false if no value is set" do
      resource = Puppet::Resource.new("File", "/foo")

      Puppet::Resource.from_data_hash(PSON.parse(resource.to_pson)).exported?.should be_false
    end

    it "should set all of its parameters as the 'parameters' entry" do
      resource = Puppet::Resource.new("File", "/foo")
      resource[:foo] = %w{bar eh}
      resource[:fee] = %w{baz}

      result = Puppet::Resource.from_data_hash(PSON.parse(resource.to_pson))
      result["foo"].should == %w{bar eh}
      result["fee"].should == %w{baz}
    end

    it "should serialize relationships as reference strings" do
      resource = Puppet::Resource.new("File", "/foo")
      resource[:requires] = Puppet::Resource.new("File", "/bar")
      result = Puppet::Resource.from_data_hash(PSON.parse(resource.to_pson))
      result[:requires].should == "File[/bar]"
    end

    it "should serialize multiple relationships as arrays of reference strings" do
      resource = Puppet::Resource.new("File", "/foo")
      resource[:requires] = [Puppet::Resource.new("File", "/bar"), Puppet::Resource.new("File", "/baz")]
      result = Puppet::Resource.from_data_hash(PSON.parse(resource.to_pson))
      result[:requires].should == [ "File[/bar]",  "File[/baz]" ]
    end
  end

  describe "when converting from pson" do
    def pson_result_should
      Puppet::Resource.expects(:new).with { |hash| yield hash }
    end

    before do
      @data = {
        'type' => "file",
        'title' => basepath+"/yay",
      }
    end

    it "should set its type to the provided type" do
      Puppet::Resource.from_data_hash(@data).type.should == "File"
    end

    it "should set its title to the provided title" do
      Puppet::Resource.from_data_hash(@data).title.should == basepath+"/yay"
    end

    it "should tag the resource with any provided tags" do
      @data['tags'] = %w{foo bar}
      resource = Puppet::Resource.from_data_hash(@data)
      resource.tags.should be_include("foo")
      resource.tags.should be_include("bar")
    end

    it "should set its file to the provided file" do
      @data['file'] = "/foo/bar"
      Puppet::Resource.from_data_hash(@data).file.should == "/foo/bar"
    end

    it "should set its line to the provided line" do
      @data['line'] = 50
      Puppet::Resource.from_data_hash(@data).line.should == 50
    end

    it "should 'exported' to true if set in the pson data" do
      @data['exported'] = true
      Puppet::Resource.from_data_hash(@data).exported.should be_true
    end

    it "should 'exported' to false if not set in the pson data" do
      Puppet::Resource.from_data_hash(@data).exported.should be_false
    end

    it "should fail if no title is provided" do
      @data.delete('title')
      expect { Puppet::Resource.from_data_hash(@data) }.to raise_error(ArgumentError)
    end

    it "should fail if no type is provided" do
      @data.delete('type')
      expect { Puppet::Resource.from_data_hash(@data) }.to raise_error(ArgumentError)
    end

    it "should set each of the provided parameters" do
      @data['parameters'] = {'foo' => %w{one two}, 'fee' => %w{three four}}
      resource = Puppet::Resource.from_data_hash(@data)
      resource['foo'].should == %w{one two}
      resource['fee'].should == %w{three four}
    end

    it "should convert single-value array parameters to normal values" do
      @data['parameters'] = {'foo' => %w{one}}
      resource = Puppet::Resource.from_data_hash(@data)
      resource['foo'].should == %w{one}
    end
  end

  it "implements copy_as_resource" do
    resource = Puppet::Resource.new("file", "/my/file")
    resource.copy_as_resource.should == resource
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

  describe '#parse_title' do
    describe 'with a composite namevar' do
      before do
        Puppet::Type.newtype(:composite) do

          newparam(:name)
          newparam(:value)

          # Configure two title patterns to match a title that is either
          # separated with a colon or exclamation point. The first capture
          # will be used for the :name param, and the second capture will be
          # used for the :value param.
          def self.title_patterns
            identity = lambda {|x| x }
            reverse  = lambda {|x| x.reverse }
            [
              [
                /^(.*?):(.*?)$/,
                [
                  [:name, identity],
                  [:value, identity],
                ]
              ],
              [
                /^(.*?)!(.*?)$/,
                [
                  [:name, reverse],
                  [:value, reverse],
                ]
              ],
            ]
          end
        end
      end

      describe "with no matching title patterns" do
        subject { Puppet::Resource.new(:composite, 'unmatching title')}

        it "should raise an exception if no title patterns match" do
          expect do
            subject.to_hash
          end.to raise_error(Puppet::Error, /No set of title patterns matched/)
        end
      end

      describe "with a matching title pattern" do
        subject { Puppet::Resource.new(:composite, 'matching:title') }

        it "should not raise an exception if there was a match" do
          expect do
            subject.to_hash
          end.to_not raise_error
        end

        it "should set the resource parameters from the parsed title values" do
          h = subject.to_hash
          h[:name].should == 'matching'
          h[:value].should == 'title'
        end
      end

      describe "and multiple title patterns" do
        subject { Puppet::Resource.new(:composite, 'matching!title') }

        it "should use the first title pattern that matches" do
          h = subject.to_hash
          h[:name].should == 'gnihctam'
          h[:value].should == 'eltit'
        end
      end
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
