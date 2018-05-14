#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'

require 'matchers/json'

describe Puppet::Resource::Catalog, "when compiling" do
  include JSONMatchers
  include PuppetSpec::Files

  before do
    @basepath = make_absolute("/somepath")
    # stub this to not try to create state.yaml
    Puppet::Util::Storage.stubs(:store)
  end

  it "should support json, pson, dot, yaml" do
    # msgpack is optional, so using include instead of eq
    expect(Puppet::Resource::Catalog.supported_formats).to include(:json, :pson, :dot, :yaml)
  end

  # audit only resources are unmanaged
  # as are resources without properties with should values
  it "should write its managed resources' types, namevars" do
    catalog = Puppet::Resource::Catalog.new("host")

    resourcefile = tmpfile('resourcefile')
    Puppet[:resourcefile] = resourcefile

    res = Puppet::Type.type('file').new(:title => File.expand_path('/tmp/sam'), :ensure => 'present')
    res.file = 'site.pp'
    res.line = 21

    res2 = Puppet::Type.type('exec').new(:title => 'bob', :command => "#{File.expand_path('/bin/rm')} -rf /")
    res2.file = File.expand_path('/modules/bob/manifests/bob.pp')
    res2.line = 42

    res3 = Puppet::Type.type('file').new(:title => File.expand_path('/tmp/susan'), :audit => 'all')
    res3.file = 'site.pp'
    res3.line = 63

    res4 = Puppet::Type.type('file').new(:title => File.expand_path('/tmp/lilly'))
    res4.file = 'site.pp'
    res4.line = 84

    comp_res = Puppet::Type.type('component').new(:title => 'Class[Main]')

    catalog.add_resource(res, res2, res3, res4, comp_res)
    catalog.write_resource_file
    expect(File.readlines(resourcefile).map(&:chomp)).to match_array([
      "file[#{File.expand_path('/tmp/sam')}]",
      "exec[#{File.expand_path('/bin/rm')} -rf /]"
    ])
  end

  it "should log an error if unable to write to the resource file" do
    catalog = Puppet::Resource::Catalog.new("host")
    Puppet[:resourcefile] = File.expand_path('/not/writable/file')

    catalog.add_resource(Puppet::Type.type('file').new(:title => File.expand_path('/tmp/foo')))
    catalog.write_resource_file
    expect(@logs.size).to eq(1)
    expect(@logs.first.message).to match(/Could not create resource file/)
    expect(@logs.first.level).to eq(:err)
  end

  it "should be able to write its list of classes to the class file" do
    @catalog = Puppet::Resource::Catalog.new("host")

    @catalog.add_class "foo", "bar"

    Puppet[:classfile] = File.expand_path("/class/file")

    fh = mock 'filehandle'
    classfile = Puppet.settings.setting(:classfile)
    Puppet::FileSystem.expects(:open).with(classfile.value, classfile.mode.to_i(8), "w:UTF-8").yields fh

    fh.expects(:puts).with "foo\nbar"

    @catalog.write_class_file
  end

  it "should have a client_version attribute" do
    @catalog = Puppet::Resource::Catalog.new("host")
    @catalog.client_version = 5
    expect(@catalog.client_version).to eq(5)
  end

  it "should have a server_version attribute" do
    @catalog = Puppet::Resource::Catalog.new("host")
    @catalog.server_version = 5
    expect(@catalog.server_version).to eq(5)
  end

  it "defaults code_id to nil" do
    catalog = Puppet::Resource::Catalog.new("host")
    expect(catalog.code_id).to be_nil
  end

  it "should include a catalog_uuid" do
    SecureRandom.stubs(:uuid).returns ("827a74c8-cf98-44da-9ff7-18c5e4bee41e")
    catalog = Puppet::Resource::Catalog.new("host")
    expect(catalog.catalog_uuid).to eq("827a74c8-cf98-44da-9ff7-18c5e4bee41e")
  end

  it "should include the current catalog_format" do
    catalog = Puppet::Resource::Catalog.new("host")
    expect(catalog.catalog_format).to eq(1)
  end

  describe "when compiling" do
    it "should accept tags" do
      config = Puppet::Resource::Catalog.new("mynode")
      config.tag("one")
      expect(config).to be_tagged("one")
    end

    it "should accept multiple tags at once" do
      config = Puppet::Resource::Catalog.new("mynode")
      config.tag("one", "two")
      expect(config).to be_tagged("one")
      expect(config).to be_tagged("two")
    end

    it "should convert all tags to strings" do
      config = Puppet::Resource::Catalog.new("mynode")
      config.tag("one", :two)
      expect(config).to be_tagged("one")
      expect(config).to be_tagged("two")
    end

    it "should tag with both the qualified name and the split name" do
      config = Puppet::Resource::Catalog.new("mynode")
      config.tag("one::two")
      expect(config).to be_tagged("one")
      expect(config).to be_tagged("one::two")
    end

    it "should accept classes" do
      config = Puppet::Resource::Catalog.new("mynode")
      config.add_class("one")
      expect(config.classes).to eq(%w{one})
      config.add_class("two", "three")
      expect(config.classes).to eq(%w{one two three})
    end

    it "should tag itself with passed class names" do
      config = Puppet::Resource::Catalog.new("mynode")
      config.add_class("one")
      expect(config).to be_tagged("one")
    end

    it "handles resource titles with brackets" do
      config = Puppet::Resource::Catalog.new("mynode")
      expect(config.title_key_for_ref("Notify[[foo]bar]")).to eql(["Notify", "[foo]bar"])
    end
  end

  describe "when converting to a RAL catalog" do
    before do
      @original = Puppet::Resource::Catalog.new("mynode")
      @original.tag(*%w{one two three})
      @original.add_class(*%w{four five six})

      @top            = Puppet::Resource.new :class, 'top'
      @topobject      = Puppet::Resource.new :file, @basepath+'/topobject'
      @middle         = Puppet::Resource.new :class, 'middle'
      @middleobject   = Puppet::Resource.new :file, @basepath+'/middleobject'
      @bottom         = Puppet::Resource.new :class, 'bottom'
      @bottomobject   = Puppet::Resource.new :file, @basepath+'/bottomobject'

      @resources = [@top, @topobject, @middle, @middleobject, @bottom, @bottomobject]

      @original.add_resource(*@resources)

      @original.add_edge(@top, @topobject)
      @original.add_edge(@top, @middle)
      @original.add_edge(@middle, @middleobject)
      @original.add_edge(@middle, @bottom)
      @original.add_edge(@bottom, @bottomobject)

      @catalog = @original.to_ral
    end

    it "should add all resources as RAL instances" do
      @resources.each do |resource|
        # Warning: a failure here will result in "global resource iteration is
        # deprecated" being raised, because the rspec rendering to get the
        # result tries to call `each` on the resource, and that raises.
        expect(@catalog.resource(resource.ref)).to be_a_kind_of(Puppet::Type)
      end
    end

    it "should copy the tag list to the new catalog" do
      expect(@catalog.tags.sort).to eq(@original.tags.sort)
    end

    it "should copy the class list to the new catalog" do
      expect(@catalog.classes).to eq(@original.classes)
    end

    it "should duplicate the original edges" do
      @original.edges.each do |edge|
        expect(@catalog.edge?(@catalog.resource(edge.source.ref), @catalog.resource(edge.target.ref))).to be_truthy
      end
    end

    it "should set itself as the catalog for each converted resource" do
      @catalog.vertices.each { |v| expect(v.catalog.object_id).to equal(@catalog.object_id) }
    end

    # This tests #931.
    it "should not lose track of resources whose names vary" do
      changer = Puppet::Resource.new :file, @basepath+'/test/', :parameters => {:ensure => :directory}

      config = Puppet::Resource::Catalog.new('test')
      config.add_resource(changer)
      config.add_resource(@top)

      config.add_edge(@top, changer)

      catalog = config.to_ral
      expect(catalog.resource("File[#{@basepath}/test/]")).to equal(catalog.resource("File[#{@basepath}/test]"))
    end

    after do
      # Remove all resource instances.
      @catalog.clear(true)
    end
  end

  describe "when filtering" do
    before :each do
      @original = Puppet::Resource::Catalog.new("mynode")
      @original.tag(*%w{one two three})
      @original.add_class(*%w{four five six})

      @r1 = stub_everything 'r1', :ref => "File[/a]"
      @r1.stubs(:respond_to?).with(:ref).returns(true)
      @r1.stubs(:copy_as_resource).returns(@r1)
      @r1.stubs(:is_a?).with(Puppet::Resource).returns(true)

      @r2 = stub_everything 'r2', :ref => "File[/b]"
      @r2.stubs(:respond_to?).with(:ref).returns(true)
      @r2.stubs(:copy_as_resource).returns(@r2)
      @r2.stubs(:is_a?).with(Puppet::Resource).returns(true)

      @resources = [@r1,@r2]

      @original.add_resource(@r1,@r2)
    end

    it "should transform the catalog to a resource catalog" do
      @original.expects(:to_catalog).with { |h,b| h == :to_resource }

      @original.filter
    end

    it "should scan each catalog resource in turn and apply filtering block" do
      @resources.each { |r| r.expects(:test?) }
      @original.filter do |r|
        r.test?
      end
    end

    it "should filter out resources which produce true when the filter block is evaluated" do
      expect(@original.filter do |r|
        r == @r1
      end.resource("File[/a]")).to be_nil
    end

    it "should not consider edges against resources that were filtered out" do
      @original.add_edge(@r1,@r2)
      expect(@original.filter do |r|
        r == @r1
      end.edge?(@r1,@r2)).not_to be
    end

    it "copies the version" do
      @original.version = '123'
      expect(@original.filter.version).to eq(@original.version)
    end

    it 'copies the code_id' do
      @original.code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      expect(@original.filter.code_id).to eq(@original.code_id)
    end

    it 'copies the catalog_uuid' do
      @original.catalog_uuid = '827a74c8-cf98-44da-9ff7-18c5e4bee41e'
      expect(@original.filter.catalog_uuid).to eq(@original.catalog_uuid)
    end

    it 'copies the catalog_format' do
      @original.catalog_format = 42
      expect(@original.filter.catalog_format).to eq(@original.catalog_format)
    end
  end

  describe "when functioning as a resource container" do
    before do
      @catalog = Puppet::Resource::Catalog.new("host")
      @one = Puppet::Type.type(:notify).new :name => "one"
      @two = Puppet::Type.type(:notify).new :name => "two"
      @three = Puppet::Type.type(:notify).new :name => "three"
      @dupe = Puppet::Type.type(:notify).new :name => "one"
    end

    it "should provide a method to add one or more resources" do
      @catalog.add_resource @one, @two
      expect(@catalog.resource(@one.ref)).to equal(@one)
      expect(@catalog.resource(@two.ref)).to equal(@two)
    end

    it "should add resources to the relationship graph if it exists" do
      relgraph = @catalog.relationship_graph

      @catalog.add_resource @one

      expect(relgraph).to be_vertex(@one)
    end

    it "should set itself as the resource's catalog if it is not a relationship graph" do
      @one.expects(:catalog=).with(@catalog)
      @catalog.add_resource @one
    end

    it "should make all vertices available by resource reference" do
      @catalog.add_resource(@one)
      expect(@catalog.resource(@one.ref)).to equal(@one)
      expect(@catalog.vertices.find { |r| r.ref == @one.ref }).to equal(@one)
    end

    it "tracks the container through edges" do
      @catalog.add_resource(@two)
      @catalog.add_resource(@one)

      @catalog.add_edge(@one, @two)

      expect(@catalog.container_of(@two)).to eq(@one)
    end

    it "a resource without a container is contained in nil" do
      @catalog.add_resource(@one)

      expect(@catalog.container_of(@one)).to be_nil
    end

    it "should canonize how resources are referred to during retrieval when both type and title are provided" do
      @catalog.add_resource(@one)
      expect(@catalog.resource("notify", "one")).to equal(@one)
    end

    it "should canonize how resources are referred to during retrieval when just the title is provided" do
      @catalog.add_resource(@one)
      expect(@catalog.resource("notify[one]", nil)).to equal(@one)
    end

    it "adds resources before an existing resource" do
      @catalog.add_resource(@one)
      @catalog.add_resource_before(@one, @two, @three)

      expect(@catalog.resources).to eq([@two, @three, @one])
    end

    it "raises if adding a resource before a resource not in the catalog" do
      expect {
        @catalog.add_resource_before(@one, @two)
      }.to raise_error(ArgumentError, "Cannot add resource Notify[two] before Notify[one] because Notify[one] is not yet in the catalog")
    end

    it "adds resources after an existing resource in reverse order" do
      @catalog.add_resource(@one)
      @catalog.add_resource_after(@one, @two, @three)

      expect(@catalog.resources).to eq([@one, @three, @two])
    end

    it "raises if adding a resource after a resource not in the catalog" do
      expect {
        @catalog.add_resource_after(@one, @two)
      }.to raise_error(ArgumentError, "Cannot add resource Notify[two] after Notify[one] because Notify[one] is not yet in the catalog")
    end

    describe 'with a duplicate resource' do
      def resource_at(type, name, file, line)
        resource = Puppet::Resource.new(type, name)
        resource.file = file
        resource.line = line

        Puppet::Type.type(type).new(resource)
      end

      let(:orig) { resource_at(:notify, 'duplicate-title', '/path/to/orig/file', 42) }
      let(:dupe) { resource_at(:notify, 'duplicate-title', '/path/to/dupe/file', 314) }

      it "should print the locations of the original duplicated resource" do
        @catalog.add_resource(orig)

        expect { @catalog.add_resource(dupe) }.to raise_error { |error|
          expect(error).to be_a Puppet::Resource::Catalog::DuplicateResourceError

          expect(error.message).to match %r[Duplicate declaration: Notify\[duplicate-title\] is already declared]
          expect(error.message).to match %r[at \(file: /path/to/orig/file, line: 42\)]
          expect(error.message).to match %r[cannot redeclare]
          expect(error.message).to match %r[\(file: /path/to/dupe/file, line: 314\)]
        }
      end
    end

    it "should remove all resources when asked" do
      @catalog.add_resource @one
      @catalog.add_resource @two
      @one.expects :remove
      @two.expects :remove
      @catalog.clear(true)
    end

    it "should support a mechanism for finishing resources" do
      @one.expects :finish
      @two.expects :finish
      @catalog.add_resource @one
      @catalog.add_resource @two

      @catalog.finalize
    end

    it "should make default resources when finalizing" do
      @catalog.expects(:make_default_resources)
      @catalog.finalize
    end

    it "should add default resources to the catalog upon creation" do
      @catalog.make_default_resources
      expect(@catalog.resource(:schedule, "daily")).not_to be_nil
    end

    it "should optionally support an initialization block and should finalize after such blocks" do
      @one.expects :finish
      @two.expects :finish
      Puppet::Resource::Catalog.new("host") do |conf|
        conf.add_resource @one
        conf.add_resource @two
      end
    end

    it "should inform the resource that it is the resource's catalog" do
      @one.expects(:catalog=).with(@catalog)
      @catalog.add_resource @one
    end

    it "should be able to find resources by reference" do
      @catalog.add_resource @one
      expect(@catalog.resource(@one.ref)).to equal(@one)
    end

    it "should be able to find resources by reference or by type/title tuple" do
      @catalog.add_resource @one
      expect(@catalog.resource("notify", "one")).to equal(@one)
    end

    it "should have a mechanism for removing resources" do
      @catalog.add_resource(@one)
      expect(@catalog.resource(@one.ref)).to be
      expect(@catalog.vertex?(@one)).to be_truthy

      @catalog.remove_resource(@one)
      expect(@catalog.resource(@one.ref)).to be_nil
      expect(@catalog.vertex?(@one)).to be_falsey
    end

    it "should have a method for creating aliases for resources" do
      @catalog.add_resource @one
      @catalog.alias(@one, "other")
      expect(@catalog.resource("notify", "other")).to equal(@one)
    end

    it "should ignore conflicting aliases that point to the aliased resource" do
      @catalog.alias(@one, "other")
      expect { @catalog.alias(@one, "other") }.not_to raise_error
    end

    it "should create aliases for isomorphic resources whose names do not match their titles" do
      resource = Puppet::Type::File.new(:title => "testing", :path => @basepath+"/something")

      @catalog.add_resource(resource)

      expect(@catalog.resource(:file, @basepath+"/something")).to equal(resource)
    end

    it "should not create aliases for non-isomorphic resources whose names do not match their titles" do
      resource = Puppet::Type.type(:exec).new(:title => "testing", :command => "echo", :path => %w{/bin /usr/bin /usr/local/bin})

      @catalog.add_resource(resource)

      # Yay, I've already got a 'should' method
      expect(@catalog.resource(:exec, "echo").object_id).to eq(nil.object_id)
    end

    # This test is the same as the previous, but the behaviour should be explicit.
    it "should alias using the class name from the resource reference, not the resource class name" do
      @catalog.add_resource @one
      @catalog.alias(@one, "other")
      expect(@catalog.resource("notify", "other")).to equal(@one)
    end

    it "should fail to add an alias if the aliased name already exists" do
      @catalog.add_resource @one
      expect { @catalog.alias @two, "one" }.to raise_error(ArgumentError)
    end

    it "should not fail when a resource has duplicate aliases created" do
      @catalog.add_resource @one
      expect { @catalog.alias @one, "one" }.not_to raise_error
    end

    it "should not create aliases that point back to the resource" do
      @catalog.alias(@one, "one")
      expect(@catalog.resource(:notify, "one")).to be_nil
    end

    it "should be able to look resources up by their aliases" do
      @catalog.add_resource @one
      @catalog.alias @one, "two"
      expect(@catalog.resource(:notify, "two")).to equal(@one)
    end

    it "should remove resource aliases when the target resource is removed" do
      @catalog.add_resource @one
      @catalog.alias(@one, "other")
      @one.expects :remove
      @catalog.remove_resource(@one)
      expect(@catalog.resource("notify", "other")).to be_nil
    end

    it "should add an alias for the namevar when the title and name differ on isomorphic resource types" do
      resource = Puppet::Type.type(:file).new :path => @basepath+"/something", :title => "other", :content => "blah"
      resource.expects(:isomorphic?).returns(true)
      @catalog.add_resource(resource)
      expect(@catalog.resource(:file, "other")).to equal(resource)
      expect(@catalog.resource(:file, @basepath+"/something").ref).to eq(resource.ref)
    end

    it "should not add an alias for the namevar when the title and name differ on non-isomorphic resource types" do
      resource = Puppet::Type.type(:file).new :path => @basepath+"/something", :title => "other", :content => "blah"
      resource.expects(:isomorphic?).returns(false)
      @catalog.add_resource(resource)
      expect(@catalog.resource(:file, resource.title)).to equal(resource)
      # We can't use .should here, because the resources respond to that method.
      raise "Aliased non-isomorphic resource" if @catalog.resource(:file, resource.name)
    end

    it "should provide a method to create additional resources that also registers the resource" do
      args = {:name => "/yay", :ensure => :file}
      resource = stub 'file', :ref => "File[/yay]", :catalog= => @catalog, :title => "/yay", :[] => "/yay"
      Puppet::Type.type(:file).expects(:new).with(args).returns(resource)
      @catalog.create_resource :file, args
      expect(@catalog.resource("File[/yay]")).to equal(resource)
    end

    describe "when adding resources with multiple namevars" do
      before :each do
        Puppet::Type.newtype(:multiple) do
          newparam(:color, :namevar => true)
          newparam(:designation, :namevar => true)

          def self.title_patterns
            [ [
                /^(\w+) (\w+)$/,
                [
                  [:color,  lambda{|x| x}],
                  [:designation, lambda{|x| x}]
                ]
            ] ]
          end
        end
      end

      it "should add an alias using the uniqueness key" do
        @resource = Puppet::Type.type(:multiple).new(:title => "some resource", :color => "red", :designation => "5")

        @catalog.add_resource(@resource)
        expect(@catalog.resource(:multiple, "some resource")).to eq(@resource)
        expect(@catalog.resource("Multiple[some resource]")).to eq(@resource)
        expect(@catalog.resource("Multiple[red 5]")).to eq(@resource)
      end

      it "should conflict with a resource with the same uniqueness key" do
        @resource = Puppet::Type.type(:multiple).new(:title => "some resource", :color => "red", :designation => "5")
        @other    = Puppet::Type.type(:multiple).new(:title => "another resource", :color => "red", :designation => "5")

        @catalog.add_resource(@resource)
        expect { @catalog.add_resource(@other) }.to raise_error(ArgumentError, /Cannot alias Multiple\[another resource\] to \["red", "5"\].*resource \["Multiple", "red", "5"\] already declared/)
      end

      it "should conflict when its uniqueness key matches another resource's title" do
        path = make_absolute("/tmp/foo")
        @resource = Puppet::Type.type(:file).new(:title => path)
        @other    = Puppet::Type.type(:file).new(:title => "another file", :path => path)

        @catalog.add_resource(@resource)
        expect { @catalog.add_resource(@other) }.to raise_error(ArgumentError, /Cannot alias File\[another file\] to \["#{Regexp.escape(path)}"\].*resource \["File", "#{Regexp.escape(path)}"\] already declared/)
      end

      it "should conflict when its uniqueness key matches the uniqueness key derived from another resource's title" do
        @resource = Puppet::Type.type(:multiple).new(:title => "red leader")
        @other    = Puppet::Type.type(:multiple).new(:title => "another resource", :color => "red", :designation => "leader")

        @catalog.add_resource(@resource)
        expect { @catalog.add_resource(@other) }.to raise_error(ArgumentError, /Cannot alias Multiple\[another resource\] to \["red", "leader"\].*resource \["Multiple", "red", "leader"\] already declared/)
      end
    end
  end

  describe "when applying" do
    before :each do
      @catalog = Puppet::Resource::Catalog.new("host")

      @transaction = Puppet::Transaction.new(@catalog, nil, Puppet::Graph::RandomPrioritizer.new)
      Puppet::Transaction.stubs(:new).returns(@transaction)
      @transaction.stubs(:evaluate)
      @transaction.stubs(:for_network_device=)

      Puppet.settings.stubs(:use)
    end

    it "should create and evaluate a transaction" do
      @transaction.expects(:evaluate)
      @catalog.apply
    end

    it "should add a transaction evalution time to the report" do
      @transaction.report.expects(:add_times).with(:transaction_evaluation, kind_of(Numeric))
      @catalog.apply
    end

    it "should return the transaction" do
      expect(@catalog.apply).to equal(@transaction)
    end

    it "should yield the transaction if a block is provided" do
      @catalog.apply do |trans|
        expect(trans).to equal(@transaction)
      end
    end

    it "should default to being a host catalog" do
      expect(@catalog.host_config).to be_truthy
    end

    it "should be able to be set to a non-host_config" do
      @catalog.host_config = false
      expect(@catalog.host_config).to be_falsey
    end

    it "should pass supplied tags on to the transaction" do
      @transaction.expects(:tags=).with(%w{one two})
      @catalog.apply(:tags => %w{one two})
    end

    it "should set ignoreschedules on the transaction if specified in apply()" do
      @transaction.expects(:ignoreschedules=).with(true)
      @catalog.apply(:ignoreschedules => true)
    end

    it "should detect transaction failure and report it" do
      @transaction.stubs(:evaluate).raises(RuntimeError, 'transaction failed.')
      report = Puppet::Transaction::Report.new('apply')

      expect { @catalog.apply(:report => report) }.to raise_error(RuntimeError)
      report.finalize_report

      expect(report.status).to eq('failed')
    end

    describe "host catalogs" do

      # super() doesn't work in the setup method for some reason
      before do
        @catalog.host_config = true
        Puppet::Util::Storage.stubs(:store)
      end

      it "should initialize the state database before applying a catalog" do
        Puppet::Util::Storage.expects(:load)

        # Short-circuit the apply, so we know we're loading before the transaction
        Puppet::Transaction.expects(:new).raises ArgumentError
        expect { @catalog.apply }.to raise_error(ArgumentError)
      end

      it "should sync the state database after applying" do
        Puppet::Util::Storage.expects(:store)
        @transaction.stubs :any_failed? => false
        @catalog.apply
      end

    end

    describe "non-host catalogs" do

      before do
        @catalog.host_config = false
      end

      it "should never send reports" do
        Puppet[:report] = true
        Puppet[:summarize] = true
        @catalog.apply
      end

      it "should never modify the state database" do
        Puppet::Util::Storage.expects(:load).never
        Puppet::Util::Storage.expects(:store).never
        @catalog.apply
      end

    end
  end

  describe "when creating a relationship graph" do
    before do
      @catalog = Puppet::Resource::Catalog.new("host")
    end

    it "should get removed when the catalog is cleaned up" do
      @catalog.relationship_graph.expects(:clear)

      @catalog.clear

      expect(@catalog.instance_variable_get("@relationship_graph")).to be_nil
    end
  end

  describe "when writing dot files" do
    before do
      @catalog = Puppet::Resource::Catalog.new("host")
      @name = :test
      @file = File.join(Puppet[:graphdir], @name.to_s + ".dot")
    end

    it "should only write when it is a host catalog" do
      Puppet::FileSystem.expects(:open).with(@file, 0640, "w:UTF-8").never
      @catalog.host_config = false
      Puppet[:graph] = true
      @catalog.write_graph(@name)
    end

  end

  describe "when indirecting" do
    before do
      @real_indirection = Puppet::Resource::Catalog.indirection

      @indirection = stub 'indirection', :name => :catalog
    end

    it "should use the value of the 'catalog_terminus' setting to determine its terminus class" do
      # Puppet only checks the terminus setting the first time you ask
      # so this returns the object to the clean state
      # at the expense of making this test less pure
      Puppet::Resource::Catalog.indirection.reset_terminus_class

      Puppet.settings[:catalog_terminus] = "rest"
      expect(Puppet::Resource::Catalog.indirection.terminus_class).to eq(:rest)
    end

    it "should allow the terminus class to be set manually" do
      Puppet::Resource::Catalog.indirection.terminus_class = :rest
      expect(Puppet::Resource::Catalog.indirection.terminus_class).to eq(:rest)
    end

    after do
      @real_indirection.reset_terminus_class
    end
  end

  describe "when converting to yaml" do
    before do
      @catalog = Puppet::Resource::Catalog.new("me")
      @catalog.add_edge("one", "two")
    end

    it "should be able to be dumped to yaml" do
      expect(YAML.dump(@catalog)).to be_instance_of(String)
    end
  end

  describe "when converting from yaml" do
    before do
      @catalog = Puppet::Resource::Catalog.new("me")
      @catalog.add_edge("one", "two")

      text = YAML.dump(@catalog)
      @newcatalog = YAML.load(text)
    end

    it "should get converted back to a catalog" do
      expect(@newcatalog).to be_instance_of(Puppet::Resource::Catalog)
    end

    it "should have all vertices" do
      expect(@newcatalog.vertex?("one")).to be_truthy
      expect(@newcatalog.vertex?("two")).to be_truthy
    end

    it "should have all edges" do
      expect(@newcatalog.edge?("one", "two")).to be_truthy
    end
  end
end

describe Puppet::Resource::Catalog, "when converting a resource catalog to json" do
  include JSONMatchers
  include PuppetSpec::Compiler

  it "should validate an empty catalog against the schema" do
    empty_catalog = compile_to_catalog("")
    expect(empty_catalog.to_json).to validate_against('api/schemas/catalog.json')
  end

  it "should validate a noop catalog against the schema" do
    noop_catalog = compile_to_catalog("create_resources('file', {})")
    expect(noop_catalog.to_json).to validate_against('api/schemas/catalog.json')
  end

  it "should validate a single resource catalog against the schema" do
    catalog = compile_to_catalog("create_resources('file', {'/etc/foo'=>{'ensure'=>'present'}})")
    expect(catalog.to_json).to validate_against('api/schemas/catalog.json')
  end

  it "should validate a virtual resource catalog against the schema" do
    catalog = compile_to_catalog("create_resources('@file', {'/etc/foo'=>{'ensure'=>'present'}})\nrealize(File['/etc/foo'])")
    expect(catalog.to_json).to validate_against('api/schemas/catalog.json')
  end

  it "should validate a single exported resource catalog against the schema" do
    catalog = compile_to_catalog("create_resources('@@file', {'/etc/foo'=>{'ensure'=>'present'}})")
    expect(catalog.to_json).to validate_against('api/schemas/catalog.json')
  end

  it "should validate a single sensitive parameter resource catalog against the schema" do
    catalog = compile_to_catalog("create_resources('file', {'/etc/foo'=>{'ensure'=>'present','content'=>Sensitive('hunter2')}})")
    expect(catalog.to_json).to validate_against('api/schemas/catalog.json')
  end

  it "should validate a two resource catalog against the schema" do
    catalog = compile_to_catalog("create_resources('notify', {'foo'=>{'message'=>'one'}, 'bar'=>{'message'=>'two'}})")
    expect(catalog.to_json).to validate_against('api/schemas/catalog.json')
  end

  it "should validate a two parameter class catalog against the schema" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class multi_param_class ($one, $two) {
        notify {'foo':
          message => "One is $one, two is $two",
        }
      }

      class {'multi_param_class':
        one => 'hello',
        two => 'world',
      }
    MANIFEST
    expect(catalog.to_json).to validate_against('api/schemas/catalog.json')
  end

  context 'when dealing with parameters that have non-Data values' do
    context 'and rich_data is enabled' do
      before(:each) do
        Puppet.push_context(:loaders => Puppet::Pops::Loaders.new(Puppet.lookup(:environments).get(Puppet[:environment])))
        Puppet[:rich_data] = true
      end

      after(:each) do
        Puppet[:rich_data] = false
        Puppet.pop_context
      end


      let(:catalog_w_regexp)  { compile_to_catalog("notify {'foo': message => /[a-z]+/ }") }

      it 'should generate rich value hash for parameter values that are not Data' do
        s = catalog_w_regexp.to_json
        expect(s).to include('"parameters":{"message":{"__pcore_type__":"Regexp","__pcore_value__":"[a-z]+"}}')
      end

      it 'should read and convert rich value hash containing Regexp from json' do
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog_w_regexp.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(Regexp)
        expect(message).to eql(/[a-z]+/)
      end

      it 'should read and convert rich value hash containing Version from json' do
        catalog = compile_to_catalog("notify {'foo': message => SemVer('1.0.0') }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(SemanticPuppet::Version)
        expect(message).to eql(SemanticPuppet::Version.parse('1.0.0'))
      end

      it 'should read and convert rich value hash containing VersionRange from json' do
        catalog = compile_to_catalog("notify {'foo': message => SemVerRange('>=1.0.0') }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(SemanticPuppet::VersionRange)
        expect(message).to eql(SemanticPuppet::VersionRange.parse('>=1.0.0'))
      end

      it 'should read and convert rich value hash containing Timespan from json' do
        catalog = compile_to_catalog("notify {'foo': message => Timespan(1234) }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(Puppet::Pops::Time::Timespan)
        expect(message).to eql(Puppet::Pops::Time::Timespan.parse('1234', '%S'))
      end

      it 'should read and convert rich value hash containing Timestamp from json' do
        catalog = compile_to_catalog("notify {'foo': message => Timestamp('2016-09-15T08:32:16.123 UTC') }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(Puppet::Pops::Time::Timestamp)
        expect(message).to eql(Puppet::Pops::Time::Timestamp.parse('2016-09-15T08:32:16.123 UTC'))
      end

      it 'should read and convert rich value hash containing hash with rich data from json' do
        catalog = compile_to_catalog("notify {'foo': message => { 'version' => SemVer('1.0.0'), 'time' => Timestamp('2016-09-15T08:32:16.123 UTC') }}")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(Hash)
        expect(message['version']).to eql(SemanticPuppet::Version.parse('1.0.0'))
        expect(message['time']).to eql(Puppet::Pops::Time::Timestamp.parse('2016-09-15T08:32:16.123 UTC'))
      end

      it 'should read and convert rich value hash containing an array with rich data from json' do
        catalog = compile_to_catalog("notify {'foo': message => [ SemVer('1.0.0'), Timestamp('2016-09-15T08:32:16.123 UTC') ] }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(Array)
        expect(message[0]).to eql(SemanticPuppet::Version.parse('1.0.0'))
        expect(message[1]).to eql(Puppet::Pops::Time::Timestamp.parse('2016-09-15T08:32:16.123 UTC'))
      end
    end

    context 'and rich_data is disabled' do
      before(:each) do
        Puppet[:rich_data] = false
      end

      let(:catalog_w_regexp)  { compile_to_catalog("notify {'foo': message => /[a-z]+/ }") }

      it 'should not generate rich value hash for parameter values that are not Data' do
        expect(catalog_w_regexp.to_json).not_to include('"__pcore_type__"')
      end

      it 'should convert parameter containing Regexp into strings' do
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog_w_regexp.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(String)
        expect(message).to eql('/[a-z]+/')
      end

      it 'should convert parameter containing Version into string' do
        catalog = compile_to_catalog("notify {'foo': message => SemVer('1.0.0') }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(String)
        expect(message).to eql('1.0.0')
      end

      it 'should convert parameter containing VersionRange into string' do
        catalog = compile_to_catalog("notify {'foo': message => SemVerRange('>=1.0.0') }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(String)
        expect(message).to eql('>=1.0.0')
      end

      it 'should convert parameter containing Timespan into string' do
        catalog = compile_to_catalog("notify {'foo': message => Timespan(1234) }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(String)
        expect(message).to eql('0-00:20:34.0')
      end

      it 'should convert parameter containing Timestamp into string' do
        catalog = compile_to_catalog("notify {'foo': message => Timestamp('2016-09-15T08:32:16.123 UTC') }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(String)
        expect(message).to eql('2016-09-15T08:32:16.123000000 UTC')
      end

      it 'should convert param containing array with :undef entries' do
        catalog = compile_to_catalog("notify {'foo': message => [ 10, undef, 20 ] }")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(Array)
        expect(message[0]).to eql(10)
        expect(message[1]).to eql(nil)
        expect(message[2]).to eql(20)
      end

      it 'should convert param containing hash with :undef entries' do
        catalog = compile_to_catalog("notify {'foo': message => {a => undef, b => 10}}")
        catalog2 = Puppet::Resource::Catalog.from_data_hash(JSON.parse(catalog.to_json))
        message = catalog2.resource('notify', 'foo')['message']
        expect(message).to be_a(Hash)
        expect(message.has_key?('a')).to eql(true)
        expect(message['a']).to eql(nil)
        expect(message['b']).to eql(10)
      end

    end

  end
end

describe Puppet::Resource::Catalog, "when converting to json" do
  before do
    @catalog = Puppet::Resource::Catalog.new("myhost")
  end

  { :name => 'myhost',
    :version => 42,
    :code_id => 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe',
    :catalog_uuid => '827a74c8-cf98-44da-9ff7-18c5e4bee41e',
    :catalog_format => 42
  }.each do |param, value|
    it "emits a #{param} equal to #{value.inspect}" do
      @catalog.send(param.to_s + "=", value)
      json = JSON.parse(@catalog.to_json)

      expect(json[param.to_s]).to eq(@catalog.send(param))
    end
  end

  it "emits an array of classes" do
    @catalog.add_class('foo')
    json = JSON.parse(@catalog.to_json)

    expect(json['classes']).to eq(['foo'])
  end

  it "should convert its resources to a JSON-encoded array and store it as the 'resources' data" do
    one = stub 'one', :to_data_hash => "one_resource", :ref => "Foo[one]"
    two = stub 'two', :to_data_hash => "two_resource", :ref => "Foo[two]"

    one.expects(:'[]').with(:alias).returns nil
    two.expects(:'[]').with(:alias).returns nil

    @catalog.add_resource(one)
    @catalog.add_resource(two)

    # TODO this should really guarantee sort order
    expect(JSON.parse(@catalog.to_json,:create_additions => false)['resources'].sort).to eq(["one_resource", "two_resource"].sort)

  end

  it "should convert its edges to a JSON-encoded array and store it as the 'edges' data" do
    one   = stub 'one',   :to_data_hash => "one_resource",   :ref => 'Foo[one]'
    two   = stub 'two',   :to_data_hash => "two_resource",   :ref => 'Foo[two]'
    three = stub 'three', :to_data_hash => "three_resource", :ref => 'Foo[three]'

    @catalog.add_edge(one, two)
    @catalog.add_edge(two, three)

    @catalog.edges_between(one, two  )[0].expects(:to_data_hash).returns "one_two_json"
    @catalog.edges_between(two, three)[0].expects(:to_data_hash).returns "two_three_json"

    expect(JSON.parse(@catalog.to_json,:create_additions => false)['edges'].sort).to eq(%w{one_two_json two_three_json}.sort)
  end
end

describe Puppet::Resource::Catalog, "when converting from json" do
  before do
    @data = {
      'name' => "myhost"
    }
  end

  it 'should create it with the provided name' do
    @data['version'] = 50
    @data['code_id'] = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
    @data['catalog_uuid'] = '827a74c8-cf98-44da-9ff7-18c5e4bee41e'
    @data['catalog_format'] = 42
    @data['tags'] = %w{one two}
    @data['classes'] = %w{one two}
    @data['edges'] = [Puppet::Relationship.new('File[/foo]', 'File[/bar]',
                                               :event => :one,
                                               :callback => :refresh).to_data_hash]
    @data['resources'] = [Puppet::Resource.new(:file, '/foo').to_data_hash,
                          Puppet::Resource.new(:file, '/bar').to_data_hash]


    catalog = Puppet::Resource::Catalog.from_data_hash JSON.parse @data.to_json

    expect(catalog.name).to eq('myhost')
    expect(catalog.version).to eq(@data['version'])
    expect(catalog.code_id).to eq(@data['code_id'])
    expect(catalog.catalog_uuid).to eq(@data['catalog_uuid'])
    expect(catalog.catalog_format).to eq(@data['catalog_format'])
    expect(catalog).to be_tagged('one')
    expect(catalog).to be_tagged('two')

    expect(catalog.classes).to eq(@data['classes'])
    expect(catalog.resources.collect(&:ref)).to eq(['File[/foo]', 'File[/bar]'])

    expect(catalog.edges.collect(&:event)).to eq([:one])
    expect(catalog.edges[0].source).to eq(catalog.resource(:file, '/foo'))
    expect(catalog.edges[0].target).to eq(catalog.resource(:file, '/bar'))
  end

  it "defaults the catalog_format to 0" do
    catalog = Puppet::Resource::Catalog.from_data_hash JSON.parse @data.to_json
    expect(catalog.catalog_format).to eq(0)
  end

  it "should fail if the source resource cannot be found" do
    @data['edges'] = [Puppet::Relationship.new("File[/missing]", "File[/bar]").to_data_hash]
    @data['resources'] = [Puppet::Resource.new(:file, "/bar").to_data_hash]

    expect { Puppet::Resource::Catalog.from_data_hash JSON.parse @data.to_json }.to raise_error(ArgumentError, /Could not find relationship source/)
  end

  it "should fail if the target resource cannot be found" do
    @data['edges'] = [Puppet::Relationship.new("File[/bar]", "File[/missing]").to_data_hash]
    @data['resources'] = [Puppet::Resource.new(:file, "/bar").to_data_hash]

    expect { Puppet::Resource::Catalog.from_data_hash JSON.parse @data.to_json }.to raise_error(ArgumentError, /Could not find relationship target/)
  end
end
