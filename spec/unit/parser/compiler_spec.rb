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
    return nil if (attr == :stage || attr == :alias)
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
    allow(Time).to receive(:now).and_return(now)

    @node = Puppet::Node.new("testnode",
                             :facts => Puppet::Node::Facts.new("facts", {}),
                             :environment => environment)
    @known_resource_types = environment.known_resource_types
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = Puppet::Parser::Scope.new(@compiler, :source => double('source'))
    @scope_resource = Puppet::Parser::Resource.new(:file, "/my/file", :scope => @scope)
    @scope.resource = @scope_resource
  end

  it "should fail intelligently when a class-level compile fails" do
    expect(Puppet::Parser::Compiler).to receive(:new).and_raise(ArgumentError)
    expect { Puppet::Parser::Compiler.compile(@node) }.to raise_error(Puppet::Error)
  end

  it "should use the node's environment as its environment" do
    expect(@compiler.environment).to equal(@node.environment)
  end

  it "fails if the node's environment has validation errors" do
    conflicted_environment = Puppet::Node::Environment.create(:testing, [], '/some/environment.conf/manifest.pp')
    allow(conflicted_environment).to receive(:validation_errors).and_return(['bad environment'])
    @node.environment = conflicted_environment
    expect { Puppet::Parser::Compiler.compile(@node) }.to raise_error(Puppet::Error, /Compilation has been halted because.*bad environment/)
  end

  it "should be able to return a class list containing all added classes" do
    @compiler.add_class ""
    @compiler.add_class "one"
    @compiler.add_class "two"

    expect(@compiler.classlist.sort).to eq(%w{one two}.sort)
  end

  describe "when initializing" do
    it 'should not create the settings class more than once' do
      logs = []
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        Puppet[:code] = 'undef'
        @compiler.compile

        @compiler = Puppet::Parser::Compiler.new(@node)
        Puppet[:code] = 'undef'
        @compiler.compile
      end
      warnings = logs.select { |log| log.level == :warning }.map { |log| log.message }
      expect(warnings).not_to include(/Class 'settings' is already defined/)
    end

    it "should set its node attribute" do
      expect(@compiler.node).to equal(@node)
    end

    it "the set of ast_nodes should be empty" do
      expect(@compiler.environment.known_resource_types.nodes?).to be_falsey
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

    it "should return a catalog with the specified code_id" do
      node = Puppet::Node.new("mynode")
      code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      compiler = Puppet::Parser::Compiler.new(node, :code_id => code_id)

      expect(compiler.catalog.code_id).to eq(code_id)
    end

    it "should add a 'main' stage to the catalog" do
      expect(@compiler.catalog.resource(:stage, :main)).to be_instance_of(Puppet::Parser::Resource)
    end
  end

  describe "sanitize_node" do
    it "should delete trusted from parameters" do
      node = Puppet::Node.new("mynode")
      node.parameters['trusted'] =  { :a => 42 }
      node.parameters['preserve_me'] = 'other stuff'
      compiler = Puppet::Parser::Compiler.new(node)
      sanitized = compiler.node
      expect(sanitized.parameters['trusted']).to eq(nil)
      expect(sanitized.parameters['preserve_me']).to eq('other stuff')
    end

    it "should not report trusted_data if trusted is false" do
      node = Puppet::Node.new("mynode")
      node.parameters['trusted'] = false
      compiler = Puppet::Parser::Compiler.new(node)
      sanitized = compiler.node
      expect(sanitized.trusted_data).to_not eq(false)
    end

    it "should not report trusted_data if trusted is not a hash" do
      node = Puppet::Node.new("mynode")
      node.parameters['trusted'] = 'not a hash'
      compiler = Puppet::Parser::Compiler.new(node)
      sanitized = compiler.node
      expect(sanitized.trusted_data).to_not eq('not a hash')
    end

    it "should not report trusted_data if trusted hash doesn't include known keys" do
      node = Puppet::Node.new("mynode")
      node.parameters['trusted'] = { :a => 42 }
      compiler = Puppet::Parser::Compiler.new(node)
      sanitized = compiler.node
      expect(sanitized.trusted_data).to_not eq({ :a => 42 })
    end

    it "should prefer trusted_data in the node above other plausible sources" do
      node = Puppet::Node.new("mynode")
      node.trusted_data = { 'authenticated' => true,
                           'certname'      => 'the real deal',
                           'extensions'    => 'things' }

      node.parameters['trusted'] = { 'authenticated' => true,
                                     'certname'      => 'not me',
                                     'extensions'    => 'things' }

      compiler = Puppet::Parser::Compiler.new(node)
      sanitized = compiler.node
      expect(sanitized.trusted_data).to eq({ 'authenticated' => true,
                                             'certname'      => 'the real deal',
                                             'extensions'    => 'things' })
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
      scope = double('scope')
      newscope = @compiler.newscope(scope)

      expect(newscope.parent).to equal(scope)
    end

    it "should set the parent scope of the new scope to its topscope if the parent passed in is nil" do
      newscope = @compiler.newscope(nil)

      expect(newscope.parent).to equal(@compiler.topscope)
    end
  end

  describe "when compiling" do
    it "should set node parameters as variables in the top scope" do
      params = {"a" => "b", "c" => "d"}
      allow(@node).to receive(:parameters).and_return(params)
      @compiler.compile
      expect(@compiler.topscope['a']).to eq("b")
      expect(@compiler.topscope['c']).to eq("d")
    end

    it "should set node parameters that are of Symbol type as String variables in the top scope" do
      params = {"a" => :b}
      allow(@node).to receive(:parameters).and_return(params)
      @compiler.compile
      expect(@compiler.topscope['a']).to eq("b")
    end

    it "should set the node's environment as a string variable in top scope" do
      @node.merge({'wat' => 'this is how the sausage is made'})
      @compiler.compile
      expect(@compiler.topscope['environment']).to eq("testing")
      expect(@compiler.topscope['wat']).to eq('this is how the sausage is made')
    end

    it "sets the environment based on node.environment instead of the parameters" do
      @node.parameters['environment'] = "Not actually #{@node.environment.name}"

      @compiler.compile
      expect(@compiler.topscope['environment']).to eq('testing')
    end

    it "should set the client and server versions on the catalog" do
      params = {"clientversion" => "2", "serverversion" => "3"}
      allow(@node).to receive(:parameters).and_return(params)
      @compiler.compile
      expect(@compiler.catalog.client_version).to eq("2")
      expect(@compiler.catalog.server_version).to eq("3")
    end

    it "should evaluate the main class if it exists" do
      main_class = @known_resource_types.add Puppet::Resource::Type.new(:hostclass, "")
      @compiler.topscope.source = main_class

      expect(main_class).to receive(:evaluate_code).with(be_a(Puppet::Parser::Resource))

      @compiler.compile
    end

    it "should create a new, empty 'main' if no main class exists" do
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
      colls << double("coll1-false")
      colls << double("coll2-false")
      colls.each { |c| expect(c).to receive(:evaluate).and_return(false) }

      @compiler.add_collection(colls[0])
      @compiler.add_collection(colls[1])

      allow(@compiler).to receive(:fail_on_unevaluated)
      @compiler.compile
    end

    it "should ignore builtin resources" do
      resource = resource(:file, "testing")

      @compiler.add_resource(@scope, resource)
      expect(resource).not_to receive(:evaluate)

      @compiler.compile
    end

    it "should evaluate unevaluated resources" do
      resource = CompilerTestResource.new(:file, "testing")

      @compiler.add_resource(@scope, resource)

      # We have to now mark the resource as evaluated
      expect(resource).to receive(:evaluate) { resource.evaluated = true }

      @compiler.compile
    end

    it "should not evaluate already-evaluated resources" do
      resource = resource(:file, "testing")
      allow(resource).to receive(:evaluated?).and_return(true)

      @compiler.add_resource(@scope, resource)
      expect(resource).not_to receive(:evaluate)

      @compiler.compile
    end

    it "should evaluate unevaluated resources created by evaluating other resources" do
      resource = CompilerTestResource.new(:file, "testing")
      @compiler.add_resource(@scope, resource)

      resource2 = CompilerTestResource.new(:file, "other")

      # We have to now mark the resource as evaluated
      expect(resource).to receive(:evaluate) { resource.evaluated = true; @compiler.add_resource(@scope, resource2) }
      expect(resource2).to receive(:evaluate) { resource2.evaluated = true }

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
        expect(resource).to receive(:finish)

        @compiler.add_resource(@scope, resource)

        # And one that does not
        dnf_resource = double("dnf", :ref => "File[dnf]", :type => "file", :resource_type => nil, :[] => nil, :class? => nil, :stage? => nil)

        @compiler.add_resource(@scope, dnf_resource)

        @compiler.send(:finish)
      end

      it "should call finish() in add_resource order" do
        resource1 = add_resource("finish1")
        expect(resource1).to receive(:finish).ordered

        resource2 = add_resource("finish2")
        expect(resource2).to receive(:finish).ordered

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

      expect(resource).not_to receive(:evaluate)

      @compiler.compile
    end
  end

  describe "when evaluating collections" do
    it "should evaluate each collection" do
      2.times { |i|
        coll = double('coll%s' % i)
        @compiler.add_collection(coll)

        # This is the hard part -- we have to emulate the fact that
        # collections delete themselves if they are done evaluating.
        expect(coll).to receive(:evaluate) do
          @compiler.delete_collection(coll)
        end
      }

      @compiler.compile
    end

    it "should not fail when there are unevaluated resource collections that do not refer to specific resources" do
      coll = double('coll', :evaluate => false)
      expect(coll).to receive(:unresolved_resources).and_return(nil)

      @compiler.add_collection(coll)

      expect { @compiler.compile }.not_to raise_error
    end

    it "should fail when there are unevaluated resource collections that refer to a specific resource" do
      coll = double('coll', :evaluate => false)
      expect(coll).to receive(:unresolved_resources).and_return(:something)

      @compiler.add_collection(coll)

      expect { @compiler.compile }.to raise_error(Puppet::ParseError, 'Failed to realize virtual resources something')
    end

    it "should fail when there are unevaluated resource collections that refer to multiple specific resources" do
      coll = double('coll', :evaluate => false)
      expect(coll).to receive(:unresolved_resources).and_return([:one, :two])

      @compiler.add_collection(coll)

      expect { @compiler.compile }.to raise_error(Puppet::ParseError, 'Failed to realize virtual resources one, two')
    end
  end

  describe "when evaluating relationships" do
    it "should evaluate each relationship with its catalog" do
      dep = double('dep')
      expect(dep).to receive(:evaluate).with(@compiler.catalog)
      @compiler.add_relationship dep
      @compiler.evaluate_relationships
    end
  end

  describe "when told to evaluate missing classes" do
    it "should fail if there's no source listed for the scope" do
      scope = double('scope', :source => nil)
      expect { @compiler.evaluate_classes(%w{one two}, scope) }.to raise_error(Puppet::DevError)
    end

    it "should raise an error if a class is not found" do
      expect(@scope.environment.known_resource_types).to receive(:find_hostclass).with("notfound").and_return(nil)
      expect{ @compiler.evaluate_classes(%w{notfound}, @scope) }.to raise_error(Puppet::Error, /Could not find class/)
    end

    it "should raise an error when it can't find class" do
      klasses = {'foo'=>nil}
      @node.classes = klasses
      expect{ @compiler.compile }.to raise_error(Puppet::Error, /Could not find class foo for testnode/)
    end
  end

  describe "when evaluating found classes" do
    before do
      Puppet.settings[:data_binding_terminus] = "none"
      @class = @known_resource_types.add Puppet::Resource::Type.new(:hostclass, "myclass")
      @resource = double('resource', :ref => "Class[myclass]", :type => "file")
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
      allow(@compiler.catalog).to receive(:tag)

      expect(@class).to receive(:ensure_in_catalog).with(@scope)
      allow(@scope).to receive(:class_scope).with(@class)

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
        @compiler.environment.known_resource_types.add klass
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
          @compiler.environment.known_resource_types.add klass
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
      @compiler.environment.known_resource_types.add klass
      expect { @compiler.compile }.to raise_error(Puppet::PreformattedError, /Class\[Foo\]: expects a value for parameter 'b'/)
    end

    it "should fail if invalid parameters are passed" do
      klass = {'foo'=>{'3'=>'one'}}
      @node.classes = klass
      klass = Puppet::Resource::Type.new(:hostclass, 'foo', :arguments => {})
      @compiler.environment.known_resource_types.add klass
      expect { @compiler.compile }.to raise_error(Puppet::PreformattedError, /Class\[Foo\]: has no parameter named '3'/)
    end

    it "should ensure class is in catalog without params" do
      @node.classes = {'foo'=>nil}
      foo = Puppet::Resource::Type.new(:hostclass, 'foo')
      @compiler.environment.known_resource_types.add foo
      catalog = @compiler.compile
      expect(catalog.classes).to include 'foo'
    end

    it "should not evaluate the resources created for found classes unless asked" do
      allow(@compiler.catalog).to receive(:tag)

      expect(@resource).not_to receive(:evaluate)

      expect(@class).to receive(:ensure_in_catalog).and_return(@resource)
      allow(@scope).to receive(:class_scope).with(@class)

      @compiler.evaluate_classes(%w{myclass}, @scope)
    end

    it "should immediately evaluate the resources created for found classes when asked" do
      allow(@compiler.catalog).to receive(:tag)

      expect(@resource).to receive(:evaluate)
      expect(@class).to receive(:ensure_in_catalog).and_return(@resource)
      allow(@scope).to receive(:class_scope).with(@class)

      @compiler.evaluate_classes(%w{myclass}, @scope, false)
    end

    it "should skip classes that have already been evaluated" do
      allow(@compiler.catalog).to receive(:tag)

      allow(@scope).to receive(:class_scope).with(@class).and_return(@scope)

      expect(@compiler).not_to receive(:add_resource)

      expect(@resource).not_to receive(:evaluate)

      expect(Puppet::Parser::Resource).not_to receive(:new)
      @compiler.evaluate_classes(%w{myclass}, @scope, false)
    end

    it "should skip classes previously evaluated with different capitalization" do
      allow(@compiler.catalog).to receive(:tag)
      allow(@scope.environment.known_resource_types).to receive(:find_hostclass).with("MyClass").and_return(@class)
      allow(@scope).to receive(:class_scope).with(@class).and_return(@scope)
      expect(@compiler).not_to receive(:add_resource)
      expect(@resource).not_to receive(:evaluate)
      expect(Puppet::Parser::Resource).not_to receive(:new)
      @compiler.evaluate_classes(%w{MyClass}, @scope, false)
    end
  end

  describe "when evaluating AST nodes with no AST nodes present" do
    it "should do nothing" do
      allow(@compiler.environment.known_resource_types).to receive(:nodes).and_return(false)
      expect(Puppet::Parser::Resource).not_to receive(:new)

      @compiler.send(:evaluate_ast_node)
    end
  end

  describe "when evaluating AST nodes with AST nodes present" do
    before do
      allow(@compiler.environment.known_resource_types).to receive(:nodes?).and_return(true)

      # Set some names for our test
      allow(@node).to receive(:names).and_return(%w{a b c})
      allow(@compiler.environment.known_resource_types).to receive(:node).with("a").and_return(nil)
      allow(@compiler.environment.known_resource_types).to receive(:node).with("b").and_return(nil)
      allow(@compiler.environment.known_resource_types).to receive(:node).with("c").and_return(nil)

      # It should check this last, of course.
      allow(@compiler.environment.known_resource_types).to receive(:node).with("default").and_return(nil)
    end

    it "should fail if the named node cannot be found" do
      expect { @compiler.send(:evaluate_ast_node) }.to raise_error(Puppet::ParseError)
    end

    it "should evaluate the first node class matching the node name" do
      node_class = double('node', :name => "c", :evaluate_code => nil)
      allow(@compiler.environment.known_resource_types).to receive(:node).with("c").and_return(node_class)

      node_resource = double('node resource', :ref => "Node[c]", :evaluate => nil, :type => "node")
      expect(node_class).to receive(:ensure_in_catalog).and_return(node_resource)

      @compiler.compile
    end

    it "should match the default node if no matching node can be found" do
      node_class = double('node', :name => "default", :evaluate_code => nil)
      allow(@compiler.environment.known_resource_types).to receive(:node).with("default").and_return(node_class)

      node_resource = double('node resource', :ref => "Node[default]", :evaluate => nil, :type => "node")
      expect(node_class).to receive(:ensure_in_catalog).and_return(node_resource)

      @compiler.compile
    end

    it "should evaluate the node resource immediately rather than using lazy evaluation" do
      node_class = double('node', :name => "c")
      allow(@compiler.environment.known_resource_types).to receive(:node).with("c").and_return(node_class)

      node_resource = double('node resource', :ref => "Node[c]", :type => "node")
      expect(node_class).to receive(:ensure_in_catalog).and_return(node_resource)

      expect(node_resource).to receive(:evaluate)

      @compiler.send(:evaluate_ast_node)
    end
  end

  describe 'when using meta parameters to form relationships' do
    include PuppetSpec::Compiler
    [:before, :subscribe, :notify, :require].each do | meta_p |
      it "an entry consisting of nested empty arrays is flattened for parameter #{meta_p}" do
          expect {
          node = Puppet::Node.new('someone')
          manifest = <<-"MANIFEST"
            notify{hello_kitty: message => meow, #{meta_p} => [[],[]]}
            notify{hello_kitty2: message => meow, #{meta_p} => [[],[[]],[]]}
          MANIFEST

          catalog = compile_to_catalog(manifest, node)
          catalog.to_ral
        }.not_to raise_error
      end
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

        it "raises if the class name is the same as the node definition" do
          name = node.name
          node.classes = [name]

          expect {
            compile_to_catalog(<<-MANIFEST, node)
            class #{name} {}
            node #{name} {
              include #{name}
            }
          MANIFEST
          }.to raise_error(Puppet::Error, /Class '#{name}' is already defined \(line: 1\); cannot be redefined as a node \(line: 2\) on node #{name}/)
        end

        it "evaluates the class if the node definition uses a regexp" do
          name = node.name
          node.classes = [name]

          catalog = compile_to_catalog(<<-MANIFEST, node)
            class #{name} {}
            node /#{name}/ {
              include #{name}
            }
          MANIFEST

          expect(@logs).to be_empty
          expect(catalog.resource('Class', node.name.capitalize)).to_not be_nil
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
    end
  end

  describe "when managing resource overrides" do
    before do
      @override = double('override', :ref => "File[/foo]", :type => "my")
      @resource = resource(:file, "/foo")
    end

    it "should be able to store overrides" do
      expect { @compiler.add_override(@override) }.not_to raise_error
    end

    it "should apply overrides to the appropriate resources" do
      @compiler.add_resource(@scope, @resource)
      expect(@resource).to receive(:merge).with(@override)

      @compiler.add_override(@override)

      @compiler.compile
    end

    it "should accept overrides before the related resource has been created" do
      expect(@resource).to receive(:merge).with(@override)

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
end
