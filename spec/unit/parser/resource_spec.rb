require 'spec_helper'

describe Puppet::Parser::Resource do
  before do
    environment = Puppet::Node::Environment.create(:testing, [])
    @node = Puppet::Node.new("yaynode", :environment => environment)
    @known_resource_types = environment.known_resource_types
    @compiler = Puppet::Parser::Compiler.new(@node)
    @source = newclass ""
    @scope = @compiler.topscope
  end

  def mkresource(args = {})
    args[:source] ||= @source
    args[:scope] ||= @scope

    params = args[:parameters] || {:one => "yay", :three => "rah"}
    if args[:parameters] == :none
      args.delete(:parameters)
    elsif not args[:parameters].is_a? Array
      args[:parameters] = paramify(args[:source], params)
    end

    Puppet::Parser::Resource.new("resource", "testing", args)
  end

  def param(name, value, source)
    Puppet::Parser::Resource::Param.new(:name => name, :value => value, :source => source)
  end

  def paramify(source, hash)
    hash.collect do |name, value|
      Puppet::Parser::Resource::Param.new(
        :name => name, :value => value, :source => source
      )
    end
  end

  def newclass(name)
    @known_resource_types.add Puppet::Resource::Type.new(:hostclass, name)
  end

  def newdefine(name)
    @known_resource_types.add Puppet::Resource::Type.new(:definition, name)
  end

  def newnode(name)
    @known_resource_types.add Puppet::Resource::Type.new(:node, name)
  end

  it "should get its environment from its scope" do
    scope = double('scope', :source => double("source"))
    expect(scope).to receive(:environment).and_return("foo").at_least(:once)
    expect(scope).to receive(:lookupdefaults).and_return({})
    expect(Puppet::Parser::Resource.new("file", "whatever", :scope => scope).environment).to eq("foo")
  end

  it "should use the scope's environment as its environment" do
    expect(@scope).to receive(:environment).and_return("myenv").at_least(:once)
    expect(Puppet::Parser::Resource.new("file", "whatever", :scope => @scope).environment).to eq("myenv")
  end

  it "should be isomorphic if it is builtin and models an isomorphic type" do
    expect(Puppet::Type.type(:file)).to receive(:isomorphic?).and_return(true)
    @resource = expect(Puppet::Parser::Resource.new("file", "whatever", :scope => @scope, :source => @source).isomorphic?).to be_truthy
  end

  it "should not be isomorphic if it is builtin and models a non-isomorphic type" do
    expect(Puppet::Type.type(:file)).to receive(:isomorphic?).and_return(false)
    @resource = expect(Puppet::Parser::Resource.new("file", "whatever", :scope => @scope, :source => @source).isomorphic?).to be_falsey
  end

  it "should be isomorphic if it is not builtin" do
    newdefine "whatever"
    @resource = expect(Puppet::Parser::Resource.new("whatever", "whatever", :scope => @scope, :source => @source).isomorphic?).to be_truthy
  end

  it "should have an array-indexing method for retrieving parameter values" do
    @resource = mkresource
    expect(@resource[:one]).to eq("yay")
  end

  it "should use a Puppet::Resource for converting to a ral resource" do
    trans = double('resource', :to_ral => "yay")
    @resource = mkresource
    expect(@resource).to receive(:copy_as_resource).and_return(trans)
    expect(@resource.to_ral).to eq("yay")
  end

  it "should be able to use the indexing operator to access parameters" do
    resource = Puppet::Parser::Resource.new("resource", "testing", :source => "source", :scope => @scope)
    resource["foo"] = "bar"
    expect(resource["foo"]).to eq("bar")
  end

  it "should return the title when asked for a parameter named 'title'" do
    expect(Puppet::Parser::Resource.new("resource", "testing", :source => @source, :scope => @scope)[:title]).to eq("testing")
  end

  describe "when initializing" do
    before do
      @arguments = {:scope => @scope}
    end

    it "should fail unless hash is specified" do
      expect {
        Puppet::Parser::Resource.new('file', '/my/file', nil)
      }.to raise_error(ArgumentError, /Resources require a hash as last argument/)
    end

    it "should set the reference correctly" do
      res = Puppet::Parser::Resource.new("resource", "testing", @arguments)
      expect(res.ref).to eq("Resource[testing]")
    end

    it "should be tagged with user tags" do
      tags = [ "tag1", "tag2" ]
      @arguments[:parameters] = [ param(:tag, tags , :source) ]
      res = Puppet::Parser::Resource.new("resource", "testing", @arguments)
      expect(res).to be_tagged("tag1")
      expect(res).to be_tagged("tag2")
    end
  end

  describe "when evaluating" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      source = double('source')
      allow(source).to receive(:module_name)
      @scope = Puppet::Parser::Scope.new(@compiler, :source => source)
      @catalog.add_resource(Puppet::Parser::Resource.new("stage", :main, :scope => @scope))
    end

    it "should evaluate the associated AST definition" do
      definition = newdefine "mydefine"
      res = Puppet::Parser::Resource.new("mydefine", "whatever", :scope => @scope, :source => @source, :catalog => @catalog)
      expect(definition).to receive(:evaluate_code).with(res)

      res.evaluate
    end

    it "should evaluate the associated AST class" do
      @class = newclass "myclass"
      res = Puppet::Parser::Resource.new("class", "myclass", :scope => @scope, :source => @source, :catalog => @catalog)
      expect(@class).to receive(:evaluate_code).with(res)
      res.evaluate
    end

    it "should evaluate the associated AST node" do
      nodedef = newnode("mynode")
      res = Puppet::Parser::Resource.new("node", "mynode", :scope => @scope, :source => @source, :catalog => @catalog)
      expect(nodedef).to receive(:evaluate_code).with(res)
      res.evaluate
    end

    it "should add an edge to any specified stage for class resources" do
      @compiler.environment.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "foo", {})

      other_stage = Puppet::Parser::Resource.new(:stage, "other", :scope => @scope, :catalog => @catalog)
      @compiler.add_resource(@scope, other_stage)
      resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope, :catalog => @catalog)
      resource[:stage] = 'other'
      @compiler.add_resource(@scope, resource)

      resource.evaluate

      expect(@compiler.catalog.edge?(other_stage, resource)).to be_truthy
    end

    it "should fail if an unknown stage is specified" do
      @compiler.environment.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "foo", {})

      resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope, :catalog => @catalog)
      resource[:stage] = 'other'

      expect { resource.evaluate }.to raise_error(ArgumentError, /Could not find stage other specified by/)
    end

    it "should add edges from the class resources to the parent's stage if no stage is specified" do
      foo_stage = Puppet::Parser::Resource.new(:stage, :foo_stage, :scope => @scope, :catalog => @catalog)
      @compiler.add_resource(@scope, foo_stage)
      @compiler.environment.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "foo", {})
      resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope, :catalog => @catalog)
      resource[:stage] = 'foo_stage'
      @compiler.add_resource(@scope, resource)

      resource.evaluate

      expect(@compiler.catalog).to be_edge(foo_stage, resource)
    end

    it 'should allow a resource reference to be undef' do
      Puppet.push_context({code: "notify { 'hello': message=>'yo', notify => undef }"})
      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new 'anyone')
      edges = catalog.edges.map {|e| [e.source.ref, e.target.ref]}
      expect(edges).to include(['Class[main]', 'Notify[hello]'])
    end

    it 'should evaluate class in the same file without include' do
      manifest = <<-MANIFEST
        class a($myvar = 'hello') {}
        class { 'a': myvar => 'goodbye' }
        notify { $a::myvar: }
      MANIFEST
      Puppet.push_context({code: manifest})
      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new 'anyone')
      expect(catalog.resource('Notify[goodbye]')).to be_a(Puppet::Resource)
    end

    it "should allow edges to propagate multiple levels down the scope hierarchy" do
      manifest = <<-MANIFEST
        stage { before: before => Stage[main] }

        class alpha {
          include beta
        }
        class beta {
          include gamma
        }
        class gamma { }
        class { alpha: stage => before }
      MANIFEST
      Puppet.push_context({code: manifest})

      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new 'anyone')

      # Stringify them to make for easier lookup
      edges = catalog.edges.map {|e| [e.source.ref, e.target.ref]}

      expect(edges).to include(["Stage[before]", "Class[Alpha]"])
      expect(edges).to include(["Stage[before]", "Class[Beta]"])
      expect(edges).to include(["Stage[before]", "Class[Gamma]"])
    end

    it "should use the specified stage even if the parent scope specifies one" do
      manifest = <<-MANIFEST
        stage { before: before => Stage[main], }
        stage { after: require => Stage[main], }

        class alpha {
          class { beta: stage => after }
        }
        class beta { }
        class { alpha: stage => before }
      MANIFEST
      Puppet.push_context({code: manifest})

      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new 'anyone')

      edges = catalog.edges.map {|e| [e.source.ref, e.target.ref]}

      expect(edges).to include(["Stage[before]", "Class[Alpha]"])
      expect(edges).to include(["Stage[after]", "Class[Beta]"])
    end

    it "should add edges from top-level class resources to the main stage if no stage is specified" do
      main = @compiler.catalog.resource(:stage, :main)
      @compiler.environment.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "foo", {})
      resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope, :catalog => @catalog)
      @compiler.add_resource(@scope, resource)

      resource.evaluate

      expect(@compiler.catalog).to be_edge(main, resource)
    end

    it 'should assign default value to generated resource' do
      manifest = <<-PUPPET
        define one($var) {
          notify { "${var} says hello": }
        }
        
        define two($x = $title) {
          One {
            var => $x
          }
          one { a: }
          one { b: var => 'bill'}
        }
        two { 'bob': }
      PUPPET
      Puppet.push_context({code: manifest})

      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new 'anyone')
      edges = catalog.edges.map {|e| [e.source.ref, e.target.ref]}

      expect(edges).to include(['One[a]', 'Notify[bob says hello]'])
      expect(edges).to include(['One[b]', 'Notify[bill says hello]'])
    end

    it 'should override default value with new value' do
      manifest = <<-PUPPET.unindent
        class foo {
          File {
            ensure => file,
            mode   => '644',
            owner  => 'root',
            group  => 'root',
          }
        
          file { '/tmp/foo':
            ensure  => directory
          }
        
          File['/tmp/foo'] { mode => '0755' }
        }
        include foo
        PUPPET
      Puppet.push_context({code: manifest})

      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new 'anyone')
      file = catalog.resource('File[/tmp/foo]')
      expect(file).to be_a(Puppet::Resource)
      expect(file['mode']).to eql('0755')
    end
  end

  describe 'when evaluating resource defaults' do
    let(:resource) { Puppet::Parser::Resource.new('file', 'whatever', :scope => @scope, :source => @source) }

    it 'should add all defaults available from the scope' do
      expect(@scope).to receive(:lookupdefaults).with('File').and_return(:owner => param(:owner, 'default', @source))

      expect(resource[:owner]).to eq('default')
    end

    it 'should not replace existing parameters with defaults' do
      expect(@scope).to receive(:lookupdefaults).with('File').and_return(:owner => param(:owner, 'replaced', @source))
      r = Puppet::Parser::Resource.new('file', 'whatever', :scope => @scope, :source => @source, :parameters => [ param(:owner, 'oldvalue', @source) ])
      expect(r[:owner]).to eq('oldvalue')
    end

    it 'should override defaults with new parameters' do
      expect(@scope).to receive(:lookupdefaults).with('File').and_return(:owner => param(:owner, 'replaced', @source))

      resource.set_parameter(:owner, 'newvalue')
      expect(resource[:owner]).to eq('newvalue')
    end

    it 'should add a copy of each default, rather than the actual default parameter instance' do
      newparam = param(:owner, 'default', @source)
      other = newparam.dup
      other.value = "other"
      expect(newparam).to receive(:dup).and_return(other)
      expect(@scope).to receive(:lookupdefaults).with('File').and_return(:owner => newparam)

      expect(resource[:owner]).to eq('other')
    end

    it "should tag with value of default parameter named 'tag'" do
      expect(@scope).to receive(:lookupdefaults).with('File').and_return(:tag => param(:tag, 'the_tag', @source))

      expect(resource.tags).to include('the_tag')
    end
  end

  describe "when finishing" do
    before do
      @resource = Puppet::Parser::Resource.new("file", "whatever", :scope => @scope, :source => @source)
    end

    it "should do nothing if it has already been finished" do
      @resource.finish
      expect(@resource).not_to receive(:add_scope_tags)
      @resource.finish
    end

    it "converts parameters with Sensitive values to unwrapped values and metadata" do
      @resource[:content] = Puppet::Pops::Types::PSensitiveType::Sensitive.new("hunter2")
      @resource.finish
      expect(@resource[:content]).to eq "hunter2"
      expect(@resource.sensitive_parameters).to eq [:content]
    end
  end

  describe "when being tagged" do
    before do
      @scope_resource = double('scope_resource', :tags => %w{srone srtwo})
      allow(@scope).to receive(:resource).and_return(@scope_resource)
      @resource = Puppet::Parser::Resource.new("file", "yay", :scope => @scope, :source => double('source'))
    end

    it "should get tagged with the resource type" do
      expect(@resource.tags).to be_include("file")
    end

    it "should get tagged with the title" do
      expect(@resource.tags).to be_include("yay")
    end

    it "should get tagged with each name in the title if the title is a qualified class name" do
      resource = Puppet::Parser::Resource.new("file", "one::two", :scope => @scope, :source => double('source'))
      expect(resource.tags).to be_include("one")
      expect(resource.tags).to be_include("two")
    end

    it "should get tagged with each name in the type if the type is a qualified class name" do
      resource = Puppet::Parser::Resource.new("one::two", "whatever", :scope => @scope, :source => double('source'))
      expect(resource.tags).to be_include("one")
      expect(resource.tags).to be_include("two")
    end

    it "should not get tagged with non-alphanumeric titles" do
      resource = Puppet::Parser::Resource.new("file", "this is a test", :scope => @scope, :source => double('source'))
      expect(resource.tags).not_to be_include("this is a test")
    end

    it "should fail on tags containing '*' characters" do
      expect { @resource.tag("bad*tag") }.to raise_error(Puppet::ParseError)
    end

    it "should fail on tags starting with '-' characters" do
      expect { @resource.tag("-badtag") }.to raise_error(Puppet::ParseError)
    end

    it "should fail on tags containing ' ' characters" do
      expect { @resource.tag("bad tag") }.to raise_error(Puppet::ParseError)
    end

    it "should allow alpha tags" do
      expect { @resource.tag("good_tag") }.to_not raise_error
    end
  end

  describe "when merging overrides" do
    before do
      @source = "source1"
      @resource = mkresource :source => @source
      @override = mkresource :source => @source
    end

    it "should fail when the override was not created by a parent class" do
      @override.source = "source2"
      expect(@override.source).to receive(:child_of?).with("source1").and_return(false)
      expect { @resource.merge(@override) }.to raise_error(Puppet::ParseError)
    end

    it "should succeed when the override was created in the current scope" do
      @resource.source = "source3"
      @override.source = @resource.source
      expect(@override.source).not_to receive(:child_of?).with("source3")
      params = {:a => :b, :c => :d}
      expect(@override).to receive(:parameters).and_return(params)
      expect(@resource).to receive(:override_parameter).with(:b)
      expect(@resource).to receive(:override_parameter).with(:d)
      @resource.merge(@override)
    end

    it "should succeed when a parent class created the override" do
      @resource.source = "source3"
      @override.source = "source4"
      expect(@override.source).to receive(:child_of?).with("source3").and_return(true)
      params = {:a => :b, :c => :d}
      expect(@override).to receive(:parameters).and_return(params)
      expect(@resource).to receive(:override_parameter).with(:b)
      expect(@resource).to receive(:override_parameter).with(:d)
      @resource.merge(@override)
    end

    it "should add new parameters when the parameter is not set" do
      allow(@source).to receive(:child_of?).and_return(true)
      @override.set_parameter(:testing, "value")
      @resource.merge(@override)

      expect(@resource[:testing]).to eq("value")
    end

    it "should replace existing parameter values" do
      allow(@source).to receive(:child_of?).and_return(true)
      @resource.set_parameter(:testing, "old")
      @override.set_parameter(:testing, "value")

      @resource.merge(@override)

      expect(@resource[:testing]).to eq("value")
    end

    it "should add values to the parameter when the override was created with the '+>' syntax" do
      allow(@source).to receive(:child_of?).and_return(true)
      param = Puppet::Parser::Resource::Param.new(:name => :testing, :value => "testing", :source => @resource.source)
      param.add = true

      @override.set_parameter(param)

      @resource.set_parameter(:testing, "other")

      @resource.merge(@override)

      expect(@resource[:testing]).to eq(%w{other testing})
    end

    it "should not merge parameter values when multiple resources are overriden with '+>' at once " do
      @resource_2 = mkresource :source => @source

      @resource.  set_parameter(:testing, "old_val_1")
      @resource_2.set_parameter(:testing, "old_val_2")

      allow(@source).to receive(:child_of?).and_return(true)
      param = Puppet::Parser::Resource::Param.new(:name => :testing, :value => "new_val", :source => @resource.source)
      param.add = true
      @override.set_parameter(param)

      @resource.  merge(@override)
      @resource_2.merge(@override)

      expect(@resource  [:testing]).to eq(%w{old_val_1 new_val})
      expect(@resource_2[:testing]).to eq(%w{old_val_2 new_val})
    end

    it "should promote tag overrides to real tags" do
      allow(@source).to receive(:child_of?).and_return(true)
      param = Puppet::Parser::Resource::Param.new(:name => :tag, :value => "testing", :source => @resource.source)

      @override.set_parameter(param)

      @resource.merge(@override)

      expect(@resource.tagged?("testing")).to be_truthy
    end

  end

  it "should be able to be converted to a normal resource" do
    @source = double('scope', :name => "myscope")
    @resource = mkresource :source => @source
    expect(@resource).to respond_to(:copy_as_resource)
  end

  describe "when being converted to a resource" do
    before do
      @parser_resource = mkresource :scope => @scope, :parameters => {:foo => "bar", :fee => "fum"}
    end

    it "should create an instance of Puppet::Resource" do
      expect(@parser_resource.copy_as_resource).to be_instance_of(Puppet::Resource)
    end

    it "should set the type correctly on the Puppet::Resource" do
      expect(@parser_resource.copy_as_resource.type).to eq(@parser_resource.type)
    end

    it "should set the title correctly on the Puppet::Resource" do
      expect(@parser_resource.copy_as_resource.title).to eq(@parser_resource.title)
    end

    it "should copy over all of the parameters" do
      result = @parser_resource.copy_as_resource.to_hash

      # The name will be in here, also.
      expect(result[:foo]).to eq("bar")
      expect(result[:fee]).to eq("fum")
    end

    it "should copy over the tags" do
      @parser_resource.tag "foo"
      @parser_resource.tag "bar"

      expect(@parser_resource.copy_as_resource.tags).to eq(@parser_resource.tags)
    end

    it "should copy over the line" do
      @parser_resource.line = 40
      expect(@parser_resource.copy_as_resource.line).to eq(40)
    end

    it "should copy over the file" do
      @parser_resource.file = "/my/file"
      expect(@parser_resource.copy_as_resource.file).to eq("/my/file")
    end

    it "should copy over the 'exported' value" do
      @parser_resource.exported = true
      expect(@parser_resource.copy_as_resource.exported).to be_truthy
    end

    it "should copy over the 'virtual' value" do
      @parser_resource.virtual = true
      expect(@parser_resource.copy_as_resource.virtual).to be_truthy
    end

    it "should convert any parser resource references to Puppet::Resource instances" do
      ref = Puppet::Resource.new("file", "/my/file")
      @parser_resource = mkresource :source => @source, :parameters => {:foo => "bar", :fee => ref}
      result = @parser_resource.copy_as_resource
      expect(result[:fee]).to eq(Puppet::Resource.new(:file, "/my/file"))
    end

    it "should convert any parser resource references to Puppet::Resource instances even if they are in an array" do
      ref = Puppet::Resource.new("file", "/my/file")
      @parser_resource = mkresource :source => @source, :parameters => {:foo => "bar", :fee => ["a", ref]}
      result = @parser_resource.copy_as_resource
      expect(result[:fee]).to eq(["a", Puppet::Resource.new(:file, "/my/file")])
    end

    it "should convert any parser resource references to Puppet::Resource instances even if they are in an array of array, and even deeper" do
      ref1 = Puppet::Resource.new("file", "/my/file1")
      ref2 = Puppet::Resource.new("file", "/my/file2")
      @parser_resource = mkresource :source => @source, :parameters => {:foo => "bar", :fee => ["a", [ref1,ref2]]}
      result = @parser_resource.copy_as_resource
      expect(result[:fee]).to eq(["a", Puppet::Resource.new(:file, "/my/file1"), Puppet::Resource.new(:file, "/my/file2")])
    end

    it "should fail if the same param is declared twice" do
      expect do
        @parser_resource = mkresource :source => @source, :parameters => [
          Puppet::Parser::Resource::Param.new(
            :name => :foo, :value => "bar", :source => @source
          ),
          Puppet::Parser::Resource::Param.new(
            :name => :foo, :value => "baz", :source => @source
          )
        ]
      end.to raise_error(Puppet::ParseError)
    end
  end

  describe "when setting parameters" do
    before do
      @source = newclass "foobar"
      @resource = Puppet::Parser::Resource.new :foo, "bar", :scope => @scope, :source => @source
    end

    it "should accept Param instances and add them to the parameter list" do
      param = Puppet::Parser::Resource::Param.new :name => "foo", :value => "bar", :source => @source
      @resource.set_parameter(param)
      expect(@resource["foo"]).to eq("bar")
    end

    it "should allow parameters to be set to 'false'" do
      @resource.set_parameter("myparam", false)
      expect(@resource["myparam"]).to be_falsey
    end

    it "should use its source when provided a parameter name and value" do
      @resource.set_parameter("myparam", "myvalue")
      expect(@resource["myparam"]).to eq("myvalue")
    end
  end

  # part of #629 -- the undef keyword.  Make sure 'undef' params get skipped.
  it "should not include 'undef' parameters when converting itself to a hash" do
    resource = Puppet::Parser::Resource.new "file", "/tmp/testing", :source => double("source"), :scope => @scope
    resource[:owner] = :undef
    resource[:mode] = "755"
    expect(resource.to_hash[:owner]).to be_nil
  end
end
