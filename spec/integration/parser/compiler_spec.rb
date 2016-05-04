require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

class CompilerTestResource
  attr_accessor :builtin, :virtual, :evaluated, :type, :title

  def initialize(type, title)
    @type = type
    @title = title
  end

  def [](attr)
    return nil if attr == :stage
    :main
  end

  def ref
    "#{type.to_s.capitalize}[#{title}]"
  end

  def evaluated?
    @evaluated
  end

  def builtin_type?
    @builtin
  end

  def virtual?
    @virtual
  end

  def class?
    false
  end

  def stage?
    false
  end

  def evaluate
  end

  def file
    "/fake/file/goes/here"
  end

  def line
    "42"
  end

  def resource_type
    self.class
  end
end

describe Puppet::Parser::Compiler do
  include PuppetSpec::Files
  include Matchers::Resource

  def resource(type, title)
    Puppet::Parser::Resource.new(type, title, :scope => @scope)
  end

  let(:environment) { Puppet::Node::Environment.create(:testing, []) }

  before :each do
    # Push me faster, I wanna go back in time!  (Specifically, freeze time
    # across the test since we have a bunch of version == timestamp code
    # hidden away in the implementation and we keep losing the race.)
    # --daniel 2011-04-21
    now = Time.now
    Time.stubs(:now).returns(now)

    @node = Puppet::Node.new("testnode",
                             :facts => Puppet::Node::Facts.new("facts", {}),
                             :environment => environment)
    @known_resource_types = environment.known_resource_types
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = Puppet::Parser::Scope.new(@compiler, :source => stub('source'))
    @scope_resource = Puppet::Parser::Resource.new(:file, "/my/file", :scope => @scope)
    @scope.resource = @scope_resource
  end

  it "should fail intelligently when a class-level compile fails" do
    Puppet::Parser::Compiler.expects(:new).raises ArgumentError
    expect { Puppet::Parser::Compiler.compile(@node) }.to raise_error(Puppet::Error)
  end

  it "should use the node's environment as its environment" do
    expect(@compiler.environment).to equal(@node.environment)
  end

  it "fails if the node's environment has validation errors" do
    conflicted_environment = Puppet::Node::Environment.create(:testing, [], '/some/environment.conf/manifest.pp')
    conflicted_environment.stubs(:validation_errors).returns(['bad environment'])
    @node.environment = conflicted_environment
    expect { Puppet::Parser::Compiler.compile(@node) }.to raise_error(Puppet::Error, /Compilation has been halted because.*bad environment/)
  end

  it "should include the resource type collection helper" do
    expect(Puppet::Parser::Compiler.ancestors).to be_include(Puppet::Resource::TypeCollectionHelper)
  end

  it "should be able to return a class list containing all added classes" do
    @compiler.add_class ""
    @compiler.add_class "one"
    @compiler.add_class "two"

    expect(@compiler.classlist.sort).to eq(%w{one two}.sort)
  end

  describe "when initializing" do

    it "should set its node attribute" do
      expect(@compiler.node).to equal(@node)
    end
    it "should detect when ast nodes are absent" do
      expect(@compiler.ast_nodes?).to be_falsey
    end

    it "should detect when ast nodes are present" do
      @known_resource_types.expects(:nodes?).returns true
      expect(@compiler.ast_nodes?).to be_truthy
    end

    it "should copy the known_resource_types version to the catalog" do
      expect(@compiler.catalog.version).to eq(@known_resource_types.version)
    end

    it "should copy any node classes into the class list" do
      node = Puppet::Node.new("mynode")
      node.classes = %w{foo bar}
      compiler = Puppet::Parser::Compiler.new(node)

      expect(compiler.classlist).to match_array(['foo', 'bar'])
    end

    it "should transform node class hashes into a class list" do
      node = Puppet::Node.new("mynode")
      node.classes = {'foo'=>{'one'=>'p1'}, 'bar'=>{'two'=>'p2'}}
      compiler = Puppet::Parser::Compiler.new(node)

      expect(compiler.classlist).to match_array(['foo', 'bar'])
    end

    it "should add a 'main' stage to the catalog" do
      expect(@compiler.catalog.resource(:stage, :main)).to be_instance_of(Puppet::Parser::Resource)
    end
  end

  describe "when managing scopes" do

    it "should create a top scope" do
      expect(@compiler.topscope).to be_instance_of(Puppet::Parser::Scope)
    end

    it "should be able to create new scopes" do
      expect(@compiler.newscope(@compiler.topscope)).to be_instance_of(Puppet::Parser::Scope)
    end

    it "should set the parent scope of the new scope to be the passed-in parent" do
      scope = mock 'scope'
      newscope = @compiler.newscope(scope)

      expect(newscope.parent).to equal(scope)
    end

    it "should set the parent scope of the new scope to its topscope if the parent passed in is nil" do
      scope = mock 'scope'
      newscope = @compiler.newscope(nil)

      expect(newscope.parent).to equal(@compiler.topscope)
    end
  end

  describe "when compiling" do

    def compile_methods
      [:set_node_parameters, :evaluate_main, :evaluate_ast_node, :evaluate_node_classes, :evaluate_generators, :fail_on_unevaluated,
        :finish, :store, :extract, :evaluate_relationships]
    end

    # Stub all of the main compile methods except the ones we're specifically interested in.
    def compile_stub(*except)
      (compile_methods - except).each { |m| @compiler.stubs(m) }
    end

    it "should set node parameters as variables in the top scope" do
      params = {"a" => "b", "c" => "d"}
      @node.stubs(:parameters).returns(params)
      compile_stub(:set_node_parameters)
      @compiler.compile
      expect(@compiler.topscope['a']).to eq("b")
      expect(@compiler.topscope['c']).to eq("d")
    end

    it "should set the client and server versions on the catalog" do
      params = {"clientversion" => "2", "serverversion" => "3"}
      @node.stubs(:parameters).returns(params)
      compile_stub(:set_node_parameters)
      @compiler.compile
      expect(@compiler.catalog.client_version).to eq("2")
      expect(@compiler.catalog.server_version).to eq("3")
    end

    it "should evaluate the main class if it exists" do
      compile_stub(:evaluate_main)
      main_class = @known_resource_types.add Puppet::Resource::Type.new(:hostclass, "")
      main_class.expects(:evaluate_code).with { |r| r.is_a?(Puppet::Parser::Resource) }
      @compiler.topscope.expects(:source=).with(main_class)

      @compiler.compile
    end

    it "should create a new, empty 'main' if no main class exists" do
      compile_stub(:evaluate_main)
      @compiler.compile
      expect(@known_resource_types.find_hostclass("")).to be_instance_of(Puppet::Resource::Type)
    end

    it "should add an edge between the main stage and main class" do
      @compiler.compile
      expect(stage = @compiler.catalog.resource(:stage, "main")).to be_instance_of(Puppet::Parser::Resource)
      expect(klass = @compiler.catalog.resource(:class, "")).to be_instance_of(Puppet::Parser::Resource)

      expect(@compiler.catalog.edge?(stage, klass)).to be_truthy
    end

    it "should evaluate all added collections" do
      colls = []
      # And when the collections fail to evaluate.
      colls << mock("coll1-false")
      colls << mock("coll2-false")
      colls.each { |c| c.expects(:evaluate).returns(false) }

      @compiler.add_collection(colls[0])
      @compiler.add_collection(colls[1])

      compile_stub(:evaluate_generators)
      @compiler.compile
    end

    it "should ignore builtin resources" do
      resource = resource(:file, "testing")

      @compiler.add_resource(@scope, resource)
      resource.expects(:evaluate).never

      @compiler.compile
    end

    it "should evaluate unevaluated resources" do
      resource = CompilerTestResource.new(:file, "testing")

      @compiler.add_resource(@scope, resource)

      # We have to now mark the resource as evaluated
      resource.expects(:evaluate).with { |*whatever| resource.evaluated = true }

      @compiler.compile
    end

    it "should not evaluate already-evaluated resources" do
      resource = resource(:file, "testing")
      resource.stubs(:evaluated?).returns true

      @compiler.add_resource(@scope, resource)
      resource.expects(:evaluate).never

      @compiler.compile
    end

    it "should evaluate unevaluated resources created by evaluating other resources" do
      resource = CompilerTestResource.new(:file, "testing")
      @compiler.add_resource(@scope, resource)

      resource2 = CompilerTestResource.new(:file, "other")

      # We have to now mark the resource as evaluated
      resource.expects(:evaluate).with { |*whatever| resource.evaluated = true; @compiler.add_resource(@scope, resource2) }
      resource2.expects(:evaluate).with { |*whatever| resource2.evaluated = true }


      @compiler.compile
    end

    describe "when finishing" do
      before do
        @compiler.send(:evaluate_main)
        @catalog = @compiler.catalog
      end

      def add_resource(name, parent = nil)
        resource = Puppet::Parser::Resource.new "file", name, :scope => @scope
        @compiler.add_resource(@scope, resource)
        @catalog.add_edge(parent, resource) if parent
        resource
      end

      it "should call finish() on all resources" do
        # Add a resource that does respond to :finish
        resource = Puppet::Parser::Resource.new "file", "finish", :scope => @scope
        resource.expects(:finish)

        @compiler.add_resource(@scope, resource)

        # And one that does not
        dnf_resource = stub_everything "dnf", :ref => "File[dnf]", :type => "file"

        @compiler.add_resource(@scope, dnf_resource)

        @compiler.send(:finish)
      end

      it "should call finish() in add_resource order" do
        resources = sequence('resources')

        resource1 = add_resource("finish1")
        resource1.expects(:finish).in_sequence(resources)

        resource2 = add_resource("finish2")
        resource2.expects(:finish).in_sequence(resources)

        @compiler.send(:finish)
      end

      it "should add each container's metaparams to its contained resources" do
        main = @catalog.resource(:class, :main)
        main[:noop] = true

        resource1 = add_resource("meh", main)

        @compiler.send(:finish)
        expect(resource1[:noop]).to be_truthy
      end

      it "should add metaparams recursively" do
        main = @catalog.resource(:class, :main)
        main[:noop] = true

        resource1 = add_resource("meh", main)
        resource2 = add_resource("foo", resource1)

        @compiler.send(:finish)
        expect(resource2[:noop]).to be_truthy
      end

      it "should prefer metaparams from immediate parents" do
        main = @catalog.resource(:class, :main)
        main[:noop] = true

        resource1 = add_resource("meh", main)
        resource2 = add_resource("foo", resource1)

        resource1[:noop] = false

        @compiler.send(:finish)
        expect(resource2[:noop]).to be_falsey
      end

      it "should merge tags downward" do
        main = @catalog.resource(:class, :main)
        main.tag("one")

        resource1 = add_resource("meh", main)
        resource1.tag "two"
        resource2 = add_resource("foo", resource1)

        @compiler.send(:finish)
        expect(resource2.tags).to be_include("one")
        expect(resource2.tags).to be_include("two")
      end

      it "should work if only middle resources have metaparams set" do
        main = @catalog.resource(:class, :main)

        resource1 = add_resource("meh", main)
        resource1[:noop] = true
        resource2 = add_resource("foo", resource1)

        @compiler.send(:finish)
        expect(resource2[:noop]).to be_truthy
      end
    end

    it "should return added resources in add order" do
      resource1 = resource(:file, "yay")
      @compiler.add_resource(@scope, resource1)
      resource2 = resource(:file, "youpi")
      @compiler.add_resource(@scope, resource2)

      expect(@compiler.resources).to eq([resource1, resource2])
    end

    it "should add resources that do not conflict with existing resources" do
      resource = resource(:file, "yay")
      @compiler.add_resource(@scope, resource)

      expect(@compiler.catalog).to be_vertex(resource)
    end

    it "should fail to add resources that conflict with existing resources" do
      path = make_absolute("/foo")
      file1 = resource(:file, path)
      file2 = resource(:file, path)

      @compiler.add_resource(@scope, file1)
      expect { @compiler.add_resource(@scope, file2) }.to raise_error(Puppet::Resource::Catalog::DuplicateResourceError)
    end

    it "should add an edge from the scope resource to the added resource" do
      resource = resource(:file, "yay")
      @compiler.add_resource(@scope, resource)

      expect(@compiler.catalog).to be_edge(@scope.resource, resource)
    end

    it "should not add non-class resources that don't specify a stage to the 'main' stage" do
      main = @compiler.catalog.resource(:stage, :main)
      resource = resource(:file, "foo")
      @compiler.add_resource(@scope, resource)

      expect(@compiler.catalog).not_to be_edge(main, resource)
    end

    it "should not add any parent-edges to stages" do
      stage = resource(:stage, "other")
      @compiler.add_resource(@scope, stage)

      @scope.resource = resource(:class, "foo")

      expect(@compiler.catalog.edge?(@scope.resource, stage)).to be_falsey
    end

    it "should not attempt to add stages to other stages" do
      other_stage = resource(:stage, "other")
      second_stage = resource(:stage, "second")
      @compiler.add_resource(@scope, other_stage)
      @compiler.add_resource(@scope, second_stage)

      second_stage[:stage] = "other"

      expect(@compiler.catalog.edge?(other_stage, second_stage)).to be_falsey
    end

    it "should have a method for looking up resources" do
      resource = resource(:yay, "foo")
      @compiler.add_resource(@scope, resource)
      expect(@compiler.findresource("Yay[foo]")).to equal(resource)
    end

    it "should be able to look resources up by type and title" do
      resource = resource(:yay, "foo")
      @compiler.add_resource(@scope, resource)
      expect(@compiler.findresource("Yay", "foo")).to equal(resource)
    end

    it "should not evaluate virtual defined resources" do
      resource = resource(:file, "testing")
      resource.virtual = true
      @compiler.add_resource(@scope, resource)

      resource.expects(:evaluate).never

      @compiler.compile
    end
  end

  describe "when evaluating collections" do

    it "should evaluate each collection" do
      2.times { |i|
        coll = mock 'coll%s' % i
        @compiler.add_collection(coll)

        # This is the hard part -- we have to emulate the fact that
        # collections delete themselves if they are done evaluating.
        coll.expects(:evaluate).with do
          @compiler.delete_collection(coll)
        end
      }

      @compiler.compile
    end

    it "should not fail when there are unevaluated resource collections that do not refer to specific resources" do
      coll = stub 'coll', :evaluate => false
      coll.expects(:unresolved_resources).returns(nil)

      @compiler.add_collection(coll)

      expect { @compiler.compile }.not_to raise_error
    end

    it "should fail when there are unevaluated resource collections that refer to a specific resource" do
      coll = stub 'coll', :evaluate => false
      coll.expects(:unresolved_resources).returns(:something)

      @compiler.add_collection(coll)

      expect { @compiler.compile }.to raise_error(Puppet::ParseError, 'Failed to realize virtual resources something')
    end

    it "should fail when there are unevaluated resource collections that refer to multiple specific resources" do
      coll = stub 'coll', :evaluate => false
      coll.expects(:unresolved_resources).returns([:one, :two])

      @compiler.add_collection(coll)

      expect { @compiler.compile }.to raise_error(Puppet::ParseError, 'Failed to realize virtual resources one, two')
    end

    it 'matches on container inherited tags' do
      Puppet[:code] = <<-MANIFEST
      class xport_test {
        tag('foo_bar')
        @notify { 'nbr1':
          message => 'explicitly tagged',
          tag => 'foo_bar'
        }

        @notify { 'nbr2':
          message => 'implicitly tagged'
        }

        Notify <| tag == 'foo_bar' |> {
          message => 'overridden'
        }
      }
      include xport_test
      MANIFEST

      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))

      expect(catalog).to have_resource("Notify[nbr1]").with_parameter(:message, 'overridden')
      expect(catalog).to have_resource("Notify[nbr2]").with_parameter(:message, 'overridden')
    end
  end

  describe "when evaluating relationships" do
    it "should evaluate each relationship with its catalog" do
      dep = stub 'dep'
      dep.expects(:evaluate).with(@compiler.catalog)
      @compiler.add_relationship dep
      @compiler.evaluate_relationships
    end
  end

  describe "when told to evaluate missing classes" do

    it "should fail if there's no source listed for the scope" do
      scope = stub 'scope', :source => nil
      expect { @compiler.evaluate_classes(%w{one two}, scope) }.to raise_error(Puppet::DevError)
    end

    it "should raise an error if a class is not found" do
      @scope.expects(:find_hostclass).with("notfound").returns(nil)
      expect{ @compiler.evaluate_classes(%w{notfound}, @scope) }.to raise_error(Puppet::Error, /Could not find class/)
    end

    it "should raise an error when it can't find class" do
      klasses = {'foo'=>nil}
      @node.classes = klasses
      @compiler.topscope.expects(:find_hostclass).with('foo').returns(nil)
      expect{ @compiler.compile }.to raise_error(Puppet::Error, /Could not find class foo for testnode/)
    end
  end

  describe "when evaluating found classes" do

    before do
      Puppet.settings[:data_binding_terminus] = "none"
      @class = stub 'class', :name => "my::class"
      @scope.stubs(:find_hostclass).with("myclass").returns(@class)

      @resource = stub 'resource', :ref => "Class[myclass]", :type => "file"
    end

    around do |example|
      Puppet.override(
        :environments => Puppet::Environments::Static.new(environment),
        :description => "Static loader for specs"
      ) do
        example.run
      end
    end

    it "should evaluate each class" do
      @compiler.catalog.stubs(:tag)

      @class.expects(:ensure_in_catalog).with(@scope)
      @scope.stubs(:class_scope).with(@class)

      @compiler.evaluate_classes(%w{myclass}, @scope)
    end

    describe "and the classes are specified as a hash with parameters" do
      before do
        @node.classes = {}
        @ast_obj = Puppet::Parser::AST::Leaf.new(:value => 'foo')
      end

      # Define the given class with default parameters
      def define_class(name, parameters)
        @node.classes[name] = parameters
        klass = Puppet::Resource::Type.new(:hostclass, name, :arguments => {'p1' => @ast_obj, 'p2' => @ast_obj})
        @compiler.topscope.known_resource_types.add klass
      end

      def compile
        @catalog = @compiler.compile
      end

      it "should record which classes are evaluated" do
        classes = {'foo'=>{}, 'bar::foo'=>{}, 'bar'=>{}}
        classes.each { |c, params| define_class(c, params) }
        compile()
        classes.each { |name, p| expect(@catalog.classes).to include(name) }
      end

      it "should provide default values for parameters that have no values specified" do
        define_class('foo', {})
        compile()
        expect(@catalog.resource(:class, 'foo')['p1']).to eq("foo")
      end

      it "should use any provided values" do
        define_class('foo', {'p1' => 'real_value'})
        compile()
        expect(@catalog.resource(:class, 'foo')['p1']).to eq("real_value")
      end

      it "should support providing some but not all values" do
        define_class('foo', {'p1' => 'real_value'})
        compile()
        expect(@catalog.resource(:class, 'Foo')['p1']).to eq("real_value")
        expect(@catalog.resource(:class, 'Foo')['p2']).to eq("foo")
      end

      it "should ensure each node class is in catalog and has appropriate tags" do
        klasses = ['bar::foo']
        @node.classes = klasses
        ast_obj = Puppet::Parser::AST::Leaf.new(:value => 'foo')
        klasses.each do |name|
          klass = Puppet::Resource::Type.new(:hostclass, name, :arguments => {'p1' => ast_obj, 'p2' => ast_obj})
          @compiler.topscope.known_resource_types.add klass
        end
        catalog = @compiler.compile

        r2 = catalog.resources.detect {|r| r.title == 'Bar::Foo' }
        expect(r2.tags).to eq(Puppet::Util::TagSet.new(['bar::foo', 'class', 'bar', 'foo']))
      end
    end

    it "should fail if required parameters are missing" do
      klass = {'foo'=>{'a'=>'one'}}
      @node.classes = klass
      klass = Puppet::Resource::Type.new(:hostclass, 'foo', :arguments => {'a' => nil, 'b' => nil})
      @compiler.topscope.known_resource_types.add klass
      expect { @compiler.compile }.to raise_error(Puppet::PreformattedError, /Class\[Foo\]: expects a value for parameter 'b'/)
    end

    it "should fail if invalid parameters are passed" do
      klass = {'foo'=>{'3'=>'one'}}
      @node.classes = klass
      klass = Puppet::Resource::Type.new(:hostclass, 'foo', :arguments => {})
      @compiler.topscope.known_resource_types.add klass
      expect { @compiler.compile }.to raise_error(Puppet::PreformattedError, /Class\[Foo\]: has no parameter named '3'/)
    end

    it "should ensure class is in catalog without params" do
      @node.classes = klasses = {'foo'=>nil}
      foo = Puppet::Resource::Type.new(:hostclass, 'foo')
      @compiler.topscope.known_resource_types.add foo
      catalog = @compiler.compile
      expect(catalog.classes).to include 'foo'
    end

    it "should not evaluate the resources created for found classes unless asked" do
      @compiler.catalog.stubs(:tag)

      @resource.expects(:evaluate).never

      @class.expects(:ensure_in_catalog).returns(@resource)
      @scope.stubs(:class_scope).with(@class)

      @compiler.evaluate_classes(%w{myclass}, @scope)
    end

    it "should immediately evaluate the resources created for found classes when asked" do
      @compiler.catalog.stubs(:tag)

      @resource.expects(:evaluate)
      @class.expects(:ensure_in_catalog).returns(@resource)
      @scope.stubs(:class_scope).with(@class)

      @compiler.evaluate_classes(%w{myclass}, @scope, false)
    end

    it "should skip classes that have already been evaluated" do
      @compiler.catalog.stubs(:tag)

      @scope.stubs(:class_scope).with(@class).returns(@scope)

      @compiler.expects(:add_resource).never

      @resource.expects(:evaluate).never

      Puppet::Parser::Resource.expects(:new).never
      @compiler.evaluate_classes(%w{myclass}, @scope, false)
    end

    it "should skip classes previously evaluated with different capitalization" do
      @compiler.catalog.stubs(:tag)
      @scope.stubs(:find_hostclass).with("MyClass").returns(@class)
      @scope.stubs(:class_scope).with(@class).returns(@scope)
      @compiler.expects(:add_resource).never
      @resource.expects(:evaluate).never
      Puppet::Parser::Resource.expects(:new).never
      @compiler.evaluate_classes(%w{MyClass}, @scope, false)
    end
  end

  describe "when evaluating AST nodes with no AST nodes present" do

    it "should do nothing" do
      @compiler.expects(:ast_nodes?).returns(false)
      @compiler.known_resource_types.expects(:nodes).never
      Puppet::Parser::Resource.expects(:new).never

      @compiler.send(:evaluate_ast_node)
    end
  end

  describe "when evaluating AST nodes with AST nodes present" do

    before do
      @compiler.known_resource_types.stubs(:nodes?).returns true

      # Set some names for our test
      @node.stubs(:names).returns(%w{a b c})
      @compiler.known_resource_types.stubs(:node).with("a").returns(nil)
      @compiler.known_resource_types.stubs(:node).with("b").returns(nil)
      @compiler.known_resource_types.stubs(:node).with("c").returns(nil)

      # It should check this last, of course.
      @compiler.known_resource_types.stubs(:node).with("default").returns(nil)
    end

    it "should fail if the named node cannot be found" do
      expect { @compiler.send(:evaluate_ast_node) }.to raise_error(Puppet::ParseError)
    end

    it "should evaluate the first node class matching the node name" do
      node_class = stub 'node', :name => "c", :evaluate_code => nil
      @compiler.known_resource_types.stubs(:node).with("c").returns(node_class)

      node_resource = stub 'node resource', :ref => "Node[c]", :evaluate => nil, :type => "node"
      node_class.expects(:ensure_in_catalog).returns(node_resource)

      @compiler.compile
    end

    it "should match the default node if no matching node can be found" do
      node_class = stub 'node', :name => "default", :evaluate_code => nil
      @compiler.known_resource_types.stubs(:node).with("default").returns(node_class)

      node_resource = stub 'node resource', :ref => "Node[default]", :evaluate => nil, :type => "node"
      node_class.expects(:ensure_in_catalog).returns(node_resource)

      @compiler.compile
    end

    it "should evaluate the node resource immediately rather than using lazy evaluation" do
      node_class = stub 'node', :name => "c"
      @compiler.known_resource_types.stubs(:node).with("c").returns(node_class)

      node_resource = stub 'node resource', :ref => "Node[c]", :type => "node"
      node_class.expects(:ensure_in_catalog).returns(node_resource)

      node_resource.expects(:evaluate)

      @compiler.send(:evaluate_ast_node)
    end
  end

  describe "when evaluating node classes" do
    include PuppetSpec::Compiler

    describe "when provided classes in array format" do
      let(:node) { Puppet::Node.new('someone', :classes => ['something']) }

      describe "when the class exists" do
        it "should succeed if the class is already included" do
          manifest = <<-MANIFEST
          class something {}
          include something
          MANIFEST

          catalog = compile_to_catalog(manifest, node)

          expect(catalog.resource('Class', 'Something')).not_to be_nil
        end

        it "should evaluate the class without parameters if it's not already included" do
          manifest = "class something {}"

          catalog = compile_to_catalog(manifest, node)

          expect(catalog.resource('Class', 'Something')).not_to be_nil
        end
      end

      it "should fail if the class doesn't exist" do
        expect { compile_to_catalog('', node) }.to raise_error(Puppet::Error, /Could not find class something/)
      end
    end

    describe "when provided classes in hash format" do
      describe "for classes without parameters" do
        let(:node) { Puppet::Node.new('someone', :classes => {'something' => {}}) }

        describe "when the class exists" do
          it "should succeed if the class is already included" do
            manifest = <<-MANIFEST
            class something {}
            include something
            MANIFEST

            catalog = compile_to_catalog(manifest, node)

            expect(catalog.resource('Class', 'Something')).not_to be_nil
          end

          it "should evaluate the class if it's not already included" do
            manifest = <<-MANIFEST
            class something {}
            MANIFEST

            catalog = compile_to_catalog(manifest, node)

            expect(catalog.resource('Class', 'Something')).not_to be_nil
          end
        end

        it "should fail if the class doesn't exist" do
          expect { compile_to_catalog('', node) }.to raise_error(Puppet::Error, /Could not find class something/)
        end
      end

      describe "for classes with parameters" do
        let(:node) { Puppet::Node.new('someone', :classes => {'something' => {'configuron' => 'defrabulated'}}) }

        describe "when the class exists" do
          it "should fail if the class is already included" do
            manifest = <<-MANIFEST
            class something($configuron=frabulated) {}
            include something
            MANIFEST

            expect { compile_to_catalog(manifest, node) }.to raise_error(Puppet::Error, /Class\[Something\] is already declared/)
          end

          it "should evaluate the class if it's not already included" do
            manifest = <<-MANIFEST
            class something($configuron=frabulated) {}
            MANIFEST

            catalog = compile_to_catalog(manifest, node)

            resource = catalog.resource('Class', 'Something')
            expect(resource['configuron']).to eq('defrabulated')
          end
        end

        it "should fail if the class doesn't exist" do
          expect { compile_to_catalog('', node) }.to raise_error(Puppet::Error, /Could not find class something/)
        end

        it 'evaluates classes declared with parameters before unparameterized classes' do
          node = Puppet::Node.new('someone', :classes => { 'app::web' => {}, 'app' => { 'port' => 8080 } })
          manifest = <<-MANIFEST
          class app($port = 80) { }

          class app::web($port = $app::port) inherits app {
            notify { expected: message => "$port" }
          }
          MANIFEST

          catalog = compile_to_catalog(manifest, node)

          expect(catalog).to have_resource("Class[App]").with_parameter(:port, 8080)
          expect(catalog).to have_resource("Class[App::Web]")
          expect(catalog).to have_resource("Notify[expected]").with_parameter(:message, "8080")
        end
      end

      it 'looks up default parameter values from inherited class (PUP-2532)' do
        catalog = compile_to_catalog(<<-CODE)
          class a {
            Notify { message => "defaulted" }
            include c
            notify { bye: }
          }
          class b { Notify { message => "inherited" } }
          class c inherits b { notify { hi: } }

          include a
          notify {hi_test: message => Notify[hi][message] }
          notify {bye_test: message => Notify[bye][message] }
        CODE

        expect(catalog).to have_resource("Notify[hi_test]").with_parameter(:message, "inherited")
        expect(catalog).to have_resource("Notify[bye_test]").with_parameter(:message, "defaulted")
      end
    end
  end

  describe "when managing resource overrides" do

    before do
      @override = stub 'override', :ref => "File[/foo]", :type => "my"
      @resource = resource(:file, "/foo")
    end

    it "should be able to store overrides" do
      expect { @compiler.add_override(@override) }.not_to raise_error
    end

    it "should apply overrides to the appropriate resources" do
      @compiler.add_resource(@scope, @resource)
      @resource.expects(:merge).with(@override)

      @compiler.add_override(@override)

      @compiler.compile
    end

    it "should accept overrides before the related resource has been created" do
      @resource.expects(:merge).with(@override)

      # First store the override
      @compiler.add_override(@override)

      # Then the resource
      @compiler.add_resource(@scope, @resource)

      # And compile, so they get resolved
      @compiler.compile
    end

    it "should fail if the compile is finished and resource overrides have not been applied" do
      @compiler.add_override(@override)

      expect { @compiler.compile }.to raise_error Puppet::ParseError, 'Could not find resource(s) File[/foo] for overriding'
    end
  end


  context "when converting catalog to resource" do
    it "the same environment is used for compilation as for transformation to resource form" do
        Puppet[:code] = <<-MANIFEST
          notify { 'dummy':
          }
        MANIFEST

      Puppet::Parser::Resource::Catalog.any_instance.expects(:to_resource).with do |catalog|
        Puppet.lookup(:current_environment).name == :production
      end

      Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))
    end
  end

  context 'when working with $server_facts' do
    include PuppetSpec::Compiler
    context 'and have opted in to trusted_server_facts' do
      before :each do
        Puppet[:trusted_server_facts] = true
      end

      it 'should make $trusted available' do
        node = Puppet::Node.new("testing")
        node.add_server_facts({ "server_fact" => "foo" })

        catalog = compile_to_catalog(<<-MANIFEST, node)
            notify { 'test': message => $server_facts[server_fact] }
        MANIFEST

        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, "foo")
      end

      it 'should not allow assignment to $server_facts' do
        node = Puppet::Node.new("testing")
        node.add_server_facts({ "server_fact" => "foo" })

        expect do
          compile_to_catalog(<<-MANIFEST, node)
              $server_facts = 'changed'
              notify { 'test': message => $server_facts == 'changed' }
          MANIFEST
        end.to raise_error(Puppet::PreformattedError, /Attempt to assign to a reserved variable name: '\$server_facts'.*/)
      end
    end

    context 'and have not opted in to hashed_node_data' do
      before :each do
        Puppet[:trusted_server_facts] = false
      end

      it 'should not make $server_facts available' do
        node = Puppet::Node.new("testing")
        node.add_server_facts({ "server_fact" => "foo" })

        catalog = compile_to_catalog(<<-MANIFEST, node)
            notify { 'test': message => ($server_facts == undef) }
        MANIFEST

        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, true)
      end

      it 'should allow assignment to $server_facts' do
        catalog = compile_to_catalog(<<-MANIFEST)
            $server_facts = 'changed'
            notify { 'test': message => $server_facts == 'changed' }
        MANIFEST

        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, true)
      end
    end
  end
  describe "the compiler when using future parser and evaluator" do
    include PuppetSpec::Compiler

    if Puppet.features.microsoft_windows?
      it "should be able to determine the configuration version from a local version control repository" do
        pending("Bug #14071 about semantics of Puppet::Util::Execute on Windows")
        # This should always work, because we should always be
        # in the puppet repo when we run this.
        version = %x{git rev-parse HEAD}.chomp

        Puppet.settings[:config_version] = 'git rev-parse HEAD'

        compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("testnode"))
        compiler.catalog.version.should == version
      end
    end

    it 'assigns multiple variables from a class' do
      node = Puppet::Node.new("testnodex")
      catalog = compile_to_catalog(<<-PP, node)
      class foo::bar::example($x = 100)  {
        $a = 10
        $c = undef
      }
      include foo::bar::example

      [$a, $x, $c] = Class['foo::bar::example']
      notify{'check_me': message => "$a, $x, -${c}-" }
      PP
      expect(catalog).to have_resource("Notify[check_me]").with_parameter(:message, "10, 100, --")
    end

    it 'errors on attempt to assigns multiple variables from a class when variable does not exist' do
      node = Puppet::Node.new("testnodex")
      expect do
        compile_to_catalog(<<-PP, node)
        class foo::bar::example($x = 100)  {
          $ah = 10
          $c = undef
        }
        include foo::bar::example

        [$a, $x, $c] = Class['foo::bar::example']
        notify{'check_me': message => "$a, $x, -${c}-" }
        PP
      end.to raise_error(/No value for required variable '\$foo::bar::example::a'/)
    end

    it "should not create duplicate resources when a class is referenced both directly and indirectly by the node classifier (4792)" do
      node = Puppet::Node.new("testnodex")
      node.classes = ['foo', 'bar']
      catalog = compile_to_catalog(<<-PP, node)
        class foo
        {
          notify { foo_notify: }
          include bar
        }
        class bar
        {
          notify { bar_notify: }
        }
      PP

      catalog = Puppet::Parser::Compiler.compile(node)

      expect(catalog).to have_resource("Notify[foo_notify]")
      expect(catalog).to have_resource("Notify[bar_notify]")
    end

    it 'applies defaults for defines with qualified names (PUP-2302)' do
      catalog = compile_to_catalog(<<-CODE)
        define my::thing($msg = 'foo') { notify {'check_me': message => $msg } }
        My::Thing { msg => 'evoe' }
        my::thing { 'name': }
      CODE

      expect(catalog).to have_resource("Notify[check_me]").with_parameter(:message, "evoe")
    end

    it 'Applies defaults from dynamic scopes (3x and future with reverted PUP-867)' do
      catalog = compile_to_catalog(<<-CODE)
      class a {
        Notify { message => "defaulted" }
        include b
        notify { bye: }
      }
      class b { notify { hi: } }

      include a
      CODE
      expect(catalog).to have_resource("Notify[hi]").with_parameter(:message, "defaulted")
      expect(catalog).to have_resource("Notify[bye]").with_parameter(:message, "defaulted")
    end

    it 'gets default from inherited class (PUP-867)' do
      catalog = compile_to_catalog(<<-CODE)
      class a {
        Notify { message => "defaulted" }
        include c
        notify { bye: }
      }
      class b { Notify { message => "inherited" } }
      class c inherits b { notify { hi: } }

      include a
      CODE

      expect(catalog).to have_resource("Notify[hi]").with_parameter(:message, "inherited")
      expect(catalog).to have_resource("Notify[bye]").with_parameter(:message, "defaulted")
    end

    it 'looks up default parameter values from inherited class (PUP-2532)' do
      catalog = compile_to_catalog(<<-CODE)
      class a {
        Notify { message => "defaulted" }
        include c
        notify { bye: }
      }
      class b { Notify { message => "inherited" } }
      class c inherits b { notify { hi: } }

      include a
      notify {hi_test: message => Notify[hi][message] }
      notify {bye_test: message => Notify[bye][message] }
      CODE

      expect(catalog).to have_resource("Notify[hi_test]").with_parameter(:message, "inherited")
      expect(catalog).to have_resource("Notify[bye_test]").with_parameter(:message, "defaulted")
    end

    it 'does not allow override of class parameters using a resource override expression' do
      expect do
        compile_to_catalog(<<-CODE)
          Class[a] { x => 2}
        CODE
      end.to raise_error(/Resource Override can only.*got: Class\[a\].*/)
    end

    describe "when resolving class references" do
      include Matchers::Resource
      it "should not favor local scope (with class included in topscope)" do
        catalog = compile_to_catalog(<<-PP)
          class experiment {
            class baz {
            }
            notify {"x" : require => Class[Baz] }
            notify {"y" : require => Class[Experiment::Baz] }
          }
          class baz {
          }
          include baz
          include experiment
          include experiment::baz
        PP

        expect(catalog).to have_resource("Notify[x]").with_parameter(:require, be_resource("Class[Baz]"))
        expect(catalog).to have_resource("Notify[y]").with_parameter(:require, be_resource("Class[Experiment::Baz]"))
      end

      it "should not favor local scope, (with class not included in topscope)" do
        catalog = compile_to_catalog(<<-PP)
          class experiment {
            class baz {
            }
            notify {"x" : require => Class[Baz] }
            notify {"y" : require => Class[Experiment::Baz] }
          }
          class baz {
          }
          include experiment
          include experiment::baz
        PP

        expect(catalog).to have_resource("Notify[x]").with_parameter(:require, be_resource("Class[Baz]"))
        expect(catalog).to have_resource("Notify[y]").with_parameter(:require, be_resource("Class[Experiment::Baz]"))
      end
    end

    describe "(ticket #13349) when explicitly specifying top scope" do
      ["class {'::bar::baz':}", "include ::bar::baz"].each do |include|
        describe "with #{include}" do
          it "should find the top level class" do
            catalog = compile_to_catalog(<<-MANIFEST)
              class { 'foo::test': }
              class foo::test {
              	#{include}
              }
              class bar::baz {
              	notify { 'good!': }
              }
              class foo::bar::baz {
              	notify { 'bad!': }
              }
            MANIFEST

            expect(catalog).to have_resource("Class[Bar::Baz]")
            expect(catalog).to have_resource("Notify[good!]")
            expect(catalog).not_to have_resource("Class[Foo::Bar::Baz]")
            expect(catalog).not_to have_resource("Notify[bad!]")
          end
        end
      end
    end

    it 'should recompute the version after input files are re-parsed' do
      Puppet[:code] = 'class foo { }'
      first_time = Time.at(1)
      second_time = Time.at(200)
      Time.stubs(:now).returns(first_time)
      node = Puppet::Node.new('mynode')
      expect(Puppet::Parser::Compiler.compile(node).version).to eq(first_time.to_i)
      Time.stubs(:now).returns(second_time)
      expect(Puppet::Parser::Compiler.compile(node).version).to eq(first_time.to_i) # no change because files didn't change
      Puppet[:code] = nil
      expect(Puppet::Parser::Compiler.compile(node).version).to eq(second_time.to_i)
    end

    ['define', 'class', 'node'].each do |thing|
      it "'#{thing}' is not allowed inside evaluated conditional constructs" do
        expect do
          compile_to_catalog(<<-PP)
            if true {
              #{thing} foo {
              }
              notify { decoy: }
            }
          PP
        end.to raise_error(Puppet::Error, /Classes, definitions, and nodes may only appear at toplevel/)
      end

      it "'#{thing}' is not allowed inside un-evaluated conditional constructs" do
        expect do
          compile_to_catalog(<<-PP)
            if false {
              #{thing} foo {
              }
              notify { decoy: }
            }
          PP
        end.to raise_error(Puppet::Error, /Classes, definitions, and nodes may only appear at toplevel/)
      end
    end

    describe "relationships to non existing resources when strict == :error" do
      before(:each) do
        Puppet[:strict] = :error
      end

      [ 'before',
        'subscribe',
        'notify',
        'require'].each do |meta_param|
        it "are reported as an error when formed via meta parameter #{meta_param}" do
          expect { 
            compile_to_catalog(<<-PP)
              notify{ x : #{meta_param} => Notify[tooth_fairy] }
            PP
          }.to raise_error(/Could not find resource 'Notify\[tooth_fairy\]' in parameter '#{meta_param}'/)
        end
      end
    end

    describe "relationships to non existing resources when strict == :warning" do
      before(:each) do
        Puppet[:strict] = :warning
      end

      [ 'before',
        'subscribe',
        'notify',
        'require'].each do |meta_param|
        it "are reported as a warning when formed via meta parameter #{meta_param}" do
          expect { 
            compile_to_catalog(<<-PP)
              notify{ x : #{meta_param} => Notify[tooth_fairy] }
            PP
            expect(@logs).to have_matching_log(/Could not find resource 'Notify\[tooth_fairy\]' in parameter '#{meta_param}'/)

          }.to_not raise_error()
        end
      end
    end

    describe "relationships to non existing resources when strict == :off" do
      before(:each) do
        Puppet[:strict] = :off
      end

      [ 'before',
        'subscribe',
        'notify',
        'require'].each do |meta_param|
        it "does not log an error for meta parameter #{meta_param}" do
          expect { 
            compile_to_catalog(<<-PP)
              notify{ x : #{meta_param} => Notify[tooth_fairy] }
            PP
            expect(@logs).to_not have_matching_log(/Could not find resource 'Notify\[tooth_fairy\]' in parameter '#{meta_param}'/)
          }.to_not raise_error()
        end
      end
    end

    describe "relationships can be formed" do
      def extract_name(ref)
        ref.sub(/File\[(\w+)\]/, '\1')
      end

      def assert_creates_relationships(relationship_code, expectations)
        base_manifest = <<-MANIFEST
          file { [a,b,c]:
            mode => '0644',
          }
          file { [d,e]:
            mode => '0755',
          }
        MANIFEST
        catalog = compile_to_catalog(base_manifest + relationship_code)

        resources = catalog.resources.select { |res| res.type == 'File' }

        actual_relationships, actual_subscriptions = [:before, :notify].map do |relation|
          resources.map do |res|
            dependents = Array(res[relation])
            dependents.map { |ref| [res.title, extract_name(ref)] }
          end.inject(&:concat)
        end

        expect(actual_relationships).to match_array(expectations[:relationships] || [])
        expect(actual_subscriptions).to match_array(expectations[:subscriptions] || [])
      end

      it "of regular type" do
        assert_creates_relationships("File[a] -> File[b]",
          :relationships => [['a','b']])
      end

      it "of subscription type" do
        assert_creates_relationships("File[a] ~> File[b]",
          :subscriptions => [['a', 'b']])
      end

      it "between multiple resources expressed as resource with multiple titles" do
        assert_creates_relationships("File[a,b] -> File[c,d]",
          :relationships => [['a', 'c'],
            ['b', 'c'],
            ['a', 'd'],
            ['b', 'd']])
      end

      it "between collection expressions" do
        assert_creates_relationships("File <| mode == '0644' |> -> File <| mode == '0755' |>",
          :relationships => [['a', 'd'],
            ['b', 'd'],
            ['c', 'd'],
            ['a', 'e'],
            ['b', 'e'],
            ['c', 'e']])
      end

      it "between resources expressed as Strings" do
        assert_creates_relationships("'File[a]' -> 'File[b]'",
          :relationships => [['a', 'b']])
      end

      it "between resources expressed as variables" do
        assert_creates_relationships(<<-MANIFEST, :relationships => [['a', 'b']])
          $var = File[a]
          $var -> File[b]
        MANIFEST

      end

      it "between resources expressed as case statements" do
        assert_creates_relationships(<<-MANIFEST, :relationships => [['s1', 't2']])
          $var = 10
          case $var {
            10: {
              file { s1: }
            }
            12: {
              file { s2: }
            }
          }
          ->
          case $var + 2 {
            10: {
              file { t1: }
            }
            12: {
              file { t2: }
            }
          }
        MANIFEST
      end

      it "using deep access in array" do
        assert_creates_relationships(<<-MANIFEST, :relationships => [['a', 'b']])
          $var = [ [ [ File[a], File[b] ] ] ]
          $var[0][0][0] -> $var[0][0][1]
        MANIFEST

      end

      it "using deep access in hash" do
        assert_creates_relationships(<<-MANIFEST, :relationships => [['a', 'b']])
          $var = {'foo' => {'bar' => {'source' => File[a], 'target' => File[b]}}}
          $var[foo][bar][source] -> $var[foo][bar][target]
        MANIFEST

      end

      it "using resource declarations" do
        assert_creates_relationships("file { l: } -> file { r: }", :relationships => [['l', 'r']])
      end

      it "between entries in a chain of relationships" do
        assert_creates_relationships("File[a] -> File[b] ~> File[c] <- File[d] <~ File[e]",
          :relationships => [['a', 'b'], ['d', 'c']],
          :subscriptions => [['b', 'c'], ['e', 'd']])
      end
    end

    context "when dealing with variable references" do
      it 'an initial underscore in a variable name is ok' do
        catalog = compile_to_catalog(<<-MANIFEST)
          class a { $_a = 10}
          include a
          notify { 'test': message => $a::_a }
        MANIFEST

        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, 10)
      end

      it 'an initial underscore in not ok if elsewhere than last segment' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class a { $_a = 10}
            include a
            notify { 'test': message => $_a::_a }
          MANIFEST
        end.to raise_error(/Illegal variable name/)
      end

      it 'a missing variable as default value becomes undef' do
        # strict variables not on
        catalog = compile_to_catalog(<<-MANIFEST)
        class a ($b=$x) { notify {test: message=>"yes ${undef == $b}" } }
          include a
        MANIFEST

        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, "yes true")
      end
    end

    context 'when working with the trusted data hash' do
      context 'and have opted in to hashed_node_data' do
        it 'should make $trusted available' do
          node = Puppet::Node.new("testing")
          node.trusted_data = { "data" => "value" }

          catalog = compile_to_catalog(<<-MANIFEST, node)
            notify { 'test': message => $trusted[data] }
          MANIFEST

          expect(catalog).to have_resource("Notify[test]").with_parameter(:message, "value")
        end

        it 'should not allow assignment to $trusted' do
          node = Puppet::Node.new("testing")
          node.trusted_data = { "data" => "value" }

          expect do
            compile_to_catalog(<<-MANIFEST, node)
              $trusted = 'changed'
              notify { 'test': message => $trusted == 'changed' }
            MANIFEST
          end.to raise_error(Puppet::PreformattedError, /Attempt to assign to a reserved variable name: '\$trusted'/)
        end
      end
    end

    context 'when using typed parameters in definition' do
      it 'accepts type compliant arguments' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define foo(String $x) { }
          foo { 'test': x =>'say friend' }
        MANIFEST
        expect(catalog).to have_resource("Foo[test]").with_parameter(:x, 'say friend')
      end

      it 'accepts undef as the default for an Optional argument' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define foo(Optional[String] $x = undef) {
            notify { "expected": message => $x == undef }
          }
          foo { 'test': }
        MANIFEST
        expect(catalog).to have_resource("Notify[expected]").with_parameter(:message, true)
      end

      it 'accepts anything when parameters are untyped' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
          define foo($a, $b, $c) { }
          foo { 'test': a => String, b=>10, c=>undef }
          MANIFEST
        end.to_not raise_error()
      end

      it 'denies non type compliant arguments' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Integer $x) { }
            foo { 'test': x =>'say friend' }
          MANIFEST
        end.to raise_error(/Foo\[test\]: parameter 'x' expects an Integer value, got String/)
      end

      it 'denies undef for a non-optional type' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Integer $x) { }
            foo { 'test': x => undef }
          MANIFEST
        end.to raise_error(/Foo\[test\]: parameter 'x' expects an Integer value, got Undef/)
      end

      it 'denies non type compliant default argument' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Integer $x = 'pow') { }
            foo { 'test':  }
          MANIFEST
        end.to raise_error(/Foo\[test\]: parameter 'x' expects an Integer value, got String/)
      end

      it 'denies undef as the default for a non-optional type' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Integer $x = undef) { }
            foo { 'test':  }
          MANIFEST
        end.to raise_error(/Foo\[test\]: parameter 'x' expects an Integer value, got Undef/)
      end

      it 'accepts a Resource as a Type' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define bar($text) { }
          define foo(Type[Bar] $x) {
            notify { 'test': message => $x[text] }
          }
          bar { 'joke': text => 'knock knock' }
          foo { 'test': x => Bar[joke] }
        MANIFEST
        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, 'knock knock')
      end

      it 'uses infer_set when reporting type mismatch' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Struct[{b => Integer, d=>String}] $a) { }
            foo{ bar: a => {b => 5, c => 'stuff'}}
          MANIFEST
        end.to raise_error(/Foo\[bar\]:\s+parameter 'a' expects a value for key 'd'\s+parameter 'a' unrecognized key 'c'/m)
      end
    end

    context 'when using typed parameters in class' do
      it 'accepts type compliant arguments' do
        catalog = compile_to_catalog(<<-MANIFEST)
          class foo(String $x) { }
          class { 'foo': x =>'say friend' }
        MANIFEST
        expect(catalog).to have_resource("Class[Foo]").with_parameter(:x, 'say friend')
      end

      it 'accepts undef as the default for an Optional argument' do
        catalog = compile_to_catalog(<<-MANIFEST)
          class foo(Optional[String] $x = undef) {
            notify { "expected": message => $x == undef }
          }
          class { 'foo': }
        MANIFEST
        expect(catalog).to have_resource("Notify[expected]").with_parameter(:message, true)
      end

      it 'accepts anything when parameters are untyped' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo($a, $b, $c) { }
            class { 'foo': a => String, b=>10, c=>undef }
          MANIFEST
        end.to_not raise_error()
      end

      it 'denies non type compliant arguments' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo(Integer $x) { }
            class { 'foo': x =>'say friend' }
          MANIFEST
        end.to raise_error(/Class\[Foo\]: parameter 'x' expects an Integer value, got String/)
      end

      it 'denies undef for a non-optional type' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo(Integer $x) { }
            class { 'foo': x => undef }
          MANIFEST
        end.to raise_error(/Class\[Foo\]: parameter 'x' expects an Integer value, got Undef/)
      end

      it 'denies non type compliant default argument' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo(Integer $x = 'pow') { }
            class { 'foo':  }
          MANIFEST
        end.to raise_error(/Class\[Foo\]: parameter 'x' expects an Integer value, got String/)
      end

      it 'denies undef as the default for a non-optional type' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo(Integer $x = undef) { }
            class { 'foo':  }
          MANIFEST
        end.to raise_error(/Class\[Foo\]: parameter 'x' expects an Integer value, got Undef/)
      end

      it 'accepts a Resource as a Type' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define bar($text) { }
          class foo(Type[Bar] $x) {
            notify { 'test': message => $x[text] }
          }
          bar { 'joke': text => 'knock knock' }
          class { 'foo': x => Bar[joke] }
        MANIFEST
        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, 'knock knock')
      end
    end

    context 'when using typed parameters in lambdas' do
      it 'accepts type compliant arguments' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with('value') |String $x| { notify { "$x": } }
        MANIFEST
        expect(catalog).to have_resource("Notify[value]")
      end

      it 'handles an array as a single argument' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with(['value', 'second']) |$x| { notify { "${x[0]} ${x[1]}": } }
        MANIFEST
        expect(catalog).to have_resource("Notify[value second]")
      end

      # Conditinoally left out for Ruby 1.8.x since the Proc created for the expected number of arguments will accept
      # a call with fewer arguments and then pass all arguments to the closure. The closure then receives an argument
      # array of correct size with nil values instead of an array with too few arguments
      unless RUBY_VERSION[0,3] == '1.8'
        it 'denies when missing required arguments' do
          expect do
            compile_to_catalog(<<-MANIFEST)
              with(1) |$x, $y| { }
            MANIFEST
          end.to raise_error(/Parameter \$y is required but no value was given/m)
        end
      end

      it 'accepts anything when parameters are untyped' do
        catalog = compile_to_catalog(<<-MANIFEST)
          ['value', 1, true, undef].each |$x| { notify { "value: $x": } }
        MANIFEST

        expect(catalog).to have_resource("Notify[value: value]")
        expect(catalog).to have_resource("Notify[value: 1]")
        expect(catalog).to have_resource("Notify[value: true]")
        expect(catalog).to have_resource("Notify[value: ]")
      end

      it 'accepts type-compliant, slurped arguments' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with(1, 2) |Integer *$x| { notify { "${$x[0] + $x[1]}": } }
        MANIFEST
        expect(catalog).to have_resource("Notify[3]")
      end

      it 'denies non-type-compliant arguments' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(1) |String $x| { }
          MANIFEST
        end.to raise_error(/block parameter 'x' expects a String value, got Integer/m)
      end

      it 'denies non-type-compliant, slurped arguments' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(1, "hello") |Integer *$x| { }
          MANIFEST
        end.to raise_error(/block parameter 'x' expects an Integer value, got String/m)
      end

      it 'denies non-type-compliant default argument' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(1) |$x, String $defaulted = 1| { notify { "${$x + $defaulted}": }}
          MANIFEST
        end.to raise_error(/block parameter 'defaulted' expects a String value, got Integer/m)
      end

      it 'raises an error when a default argument value is an incorrect type and there are no arguments passed' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |String $defaulted = 1| {}
          MANIFEST
        end.to raise_error(/block parameter 'defaulted' expects a String value, got Integer/m)
      end

      it 'raises an error when the default argument for a slurped parameter is an incorrect type' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |String *$defaulted = 1| {}
          MANIFEST
        end.to raise_error(/block parameter 'defaulted' expects a String value, got Integer/m)
      end

      it 'allows using an array as the default slurped value' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with() |String *$defaulted = [hi]| { notify { $defaulted[0]: } }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
      end

      it 'allows using a value of the type as the default slurped value' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with() |String *$defaulted = hi| { notify { $defaulted[0]: } }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
      end

      it 'allows specifying the type of a slurped parameter as an array' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with() |Array[String] *$defaulted = hi| { notify { $defaulted[0]: } }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
      end

      it 'raises an error when the number of default values does not match the parameter\'s size specification' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |Array[String, 2] *$defaulted = hi| { }
          MANIFEST
        end.to raise_error(/block expects at least 2 arguments, got 1/m)
      end

      it 'raises an error when the number of passed values does not match the parameter\'s size specification' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(hi) |Array[String, 2] *$passed| { }
          MANIFEST
        end.to raise_error(/block expects at least 2 arguments, got 1/m)
      end

      it 'matches when the number of arguments passed for a slurp parameter match the size specification' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with(hi, bye) |Array[String, 2] *$passed| {
            $passed.each |$n| { notify { $n: } }
          }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
        expect(catalog).to have_resource('Notify[bye]')
      end

      it 'raises an error when the number of allowed slurp parameters exceeds the size constraint' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(hi, bye) |Array[String, 1, 1] *$passed| { }
          MANIFEST
        end.to raise_error(/block expects 1 argument, got 2/m)
      end

      it 'allows passing slurped arrays by specifying an array of arrays' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with([hi], [bye]) |Array[Array[String, 1, 1]] *$passed| {
            notify { $passed[0][0]: }
            notify { $passed[1][0]: }
          }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
        expect(catalog).to have_resource('Notify[bye]')
      end

      it 'raises an error when a required argument follows an optional one' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |$y = first, $x, Array[String, 1] *$passed = bye| {}
          MANIFEST
        end.to raise_error(/Parameter \$x is required/)
      end

      it 'raises an error when the minimum size of a slurped argument makes it required and it follows an optional argument' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |$x = first, Array[String, 1] *$passed| {}
          MANIFEST
        end.to raise_error(/Parameter \$passed is required/)
      end

      it 'allows slurped arguments with a minimum size of 0 after an optional argument' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with() |$x = first, Array[String, 0] *$passed| {
            notify { $x: }
          }
        MANIFEST

        expect(catalog).to have_resource('Notify[first]')
      end

      it 'accepts a Resource as a Type' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define bar($text) { }
          bar { 'joke': text => 'knock knock' }

          with(Bar[joke]) |Type[Bar] $joke| { notify { "${joke[text]}": } }
        MANIFEST
        expect(catalog).to have_resource("Notify[knock knock]")
      end
    end
  end

end
