#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Node::Catalog, " when compiling" do
    it "should accept tags" do
        config = Puppet::Node::Catalog.new("mynode")
        config.tag("one")
        config.tags.should == %w{one}
    end

    it "should accept multiple tags at once" do
        config = Puppet::Node::Catalog.new("mynode")
        config.tag("one", "two")
        config.tags.should == %w{one two}
    end

    it "should convert all tags to strings" do
        config = Puppet::Node::Catalog.new("mynode")
        config.tag("one", :two)
        config.tags.should == %w{one two}
    end

    it "should tag with both the qualified name and the split name" do
        config = Puppet::Node::Catalog.new("mynode")
        config.tag("one::two")
        config.tags.include?("one").should be_true
        config.tags.include?("one::two").should be_true
    end

    it "should accept classes" do
        config = Puppet::Node::Catalog.new("mynode")
        config.add_class("one")
        config.classes.should == %w{one}
        config.add_class("two", "three")
        config.classes.should == %w{one two three}
    end

    it "should tag itself with passed class names" do
        config = Puppet::Node::Catalog.new("mynode")
        config.add_class("one")
        config.tags.should == %w{one}
    end
end

describe Puppet::Node::Catalog, " when extracting" do
    it "should return extraction result as the method result" do
        config = Puppet::Node::Catalog.new("mynode")
        config.expects(:extraction_format).returns(:whatever)
        config.expects(:extract_to_whatever).returns(:result)
        config.extract.should == :result
    end
end

describe Puppet::Node::Catalog, " when extracting transobjects" do

    def mkscope
        @parser = Puppet::Parser::Parser.new :Code => ""
        @node = Puppet::Node.new("mynode")
        @compiler = Puppet::Parser::Compiler.new(@node, @parser)

        # XXX This is ridiculous.
        @compiler.send(:evaluate_main)
        @scope = @compiler.topscope
    end

    def mkresource(type, name)
        Puppet::Parser::Resource.new(:type => type, :title => name, :source => @source, :scope => @scope)
    end

    it "should always create a TransBucket for the 'main' class" do
        config = Puppet::Node::Catalog.new("mynode")

        @scope = mkscope
        @source = mock 'source'

        main = mkresource("class", :main)
        config.add_vertex(main)

        bucket = mock 'bucket'
        bucket.expects(:classes=).with(config.classes)
        main.stubs(:builtin?).returns(false)
        main.expects(:to_transbucket).returns(bucket)

        config.extract_to_transportable.should equal(bucket)
    end

    # This isn't really a spec-style test, but I don't know how better to do it.
    it "should transform the resource graph into a tree of TransBuckets and TransObjects" do
        config = Puppet::Node::Catalog.new("mynode")

        @scope = mkscope
        @source = mock 'source'

        defined = mkresource("class", :main)
        builtin = mkresource("file", "/yay")

        config.add_edge(defined, builtin)

        bucket = []
        bucket.expects(:classes=).with(config.classes)
        defined.stubs(:builtin?).returns(false)
        defined.expects(:to_transbucket).returns(bucket)
        builtin.expects(:to_transobject).returns(:builtin)

        config.extract_to_transportable.should == [:builtin]
    end

    # Now try it with a more complicated graph -- a three tier graph, each tier
    it "should transform arbitrarily deep graphs into isomorphic trees" do
        config = Puppet::Node::Catalog.new("mynode")

        @scope = mkscope
        @scope.stubs(:tags).returns([])
        @source = mock 'source'

        # Create our scopes.
        top = mkresource "class", :main
        topbucket = []
        topbucket.expects(:classes=).with([])
        top.expects(:to_trans).returns(topbucket)
        topres = mkresource "file", "/top"
        topres.expects(:to_trans).returns(:topres)
        config.add_edge top, topres

        middle = mkresource "class", "middle"
        middle.expects(:to_trans).returns([])
        config.add_edge top, middle
        midres = mkresource "file", "/mid"
        midres.expects(:to_trans).returns(:midres)
        config.add_edge middle, midres

        bottom = mkresource "class", "bottom"
        bottom.expects(:to_trans).returns([])
        config.add_edge middle, bottom
        botres = mkresource "file", "/bot"
        botres.expects(:to_trans).returns(:botres)
        config.add_edge bottom, botres

        toparray = config.extract_to_transportable

        # This is annoying; it should look like:
        #   [[[:botres], :midres], :topres]
        # but we can't guarantee sort order.
        toparray.include?(:topres).should be_true

        midarray = toparray.find { |t| t.is_a?(Array) }
        midarray.include?(:midres).should be_true
        botarray = midarray.find { |t| t.is_a?(Array) }
        botarray.include?(:botres).should be_true
    end
end

describe Puppet::Node::Catalog, " when converting to a transobject catalog" do
    class TestResource
        attr_accessor :name, :virtual, :builtin
        def initialize(name, options = {})
            @name = name
            options.each { |p,v| send(p.to_s + "=", v) }
        end

        def ref
            if builtin?
                "File[%s]" % name
            else
                "Class[%s]" % name
            end
        end

        def virtual?
            virtual
        end

        def builtin?
            builtin
        end

        def to_transobject
            Puppet::TransObject.new(name, builtin? ? "file" : "class")
        end
    end

    before do
        @original = Puppet::Node::Catalog.new("mynode")
        @original.tag(*%w{one two three})
        @original.add_class *%w{four five six}

        @top            = TestResource.new 'top'
        @topobject      = TestResource.new 'topobject', :builtin => true
        @virtual        = TestResource.new 'virtual', :virtual => true
        @virtualobject  = TestResource.new 'virtualobject', :builtin => true, :virtual => true
        @middle         = TestResource.new 'middle'
        @middleobject   = TestResource.new 'middleobject', :builtin => true
        @bottom         = TestResource.new 'bottom'
        @bottomobject   = TestResource.new 'bottomobject', :builtin => true

        @resources = [@top, @topobject, @middle, @middleobject, @bottom, @bottomobject]

        @original.add_edge(@top, @topobject)
        @original.add_edge(@top, @virtual)
        @original.add_edge(@virtual, @virtualobject)
        @original.add_edge(@top, @middle)
        @original.add_edge(@middle, @middleobject)
        @original.add_edge(@middle, @bottom)
        @original.add_edge(@bottom, @bottomobject)

        @catalog = @original.to_transportable
    end

    it "should add all resources as TransObjects" do
        @resources.each { |resource| @catalog.resource(resource.ref).should be_instance_of(Puppet::TransObject) }
    end

    it "should not extract defined virtual resources" do
        @catalog.vertices.find { |v| v.name == "virtual" }.should be_nil
    end

    it "should not extract builtin virtual resources" do
        @catalog.vertices.find { |v| v.name == "virtualobject" }.should be_nil
    end

    it "should copy the tag list to the new catalog" do
        @catalog.tags.sort.should == @original.tags.sort
    end

    it "should copy the class list to the new catalog" do
        @catalog.classes.should == @original.classes
    end

    it "should duplicate the original edges" do
        @original.edges.each do |edge|
            next if edge.source.virtual? or edge.target.virtual?
            source = @catalog.resource(edge.source.ref)
            target = @catalog.resource(edge.target.ref)

            source.should_not be_nil
            target.should_not be_nil
            @catalog.edge?(source, target).should be_true
        end
    end

    it "should set itself as the catalog for each converted resource" do
        @catalog.vertices.each { |v| v.catalog.object_id.should equal(@catalog.object_id) }
    end
end

describe Puppet::Node::Catalog, " when converting to a RAL catalog" do
    before do
        @original = Puppet::Node::Catalog.new("mynode")
        @original.tag(*%w{one two three})
        @original.add_class *%w{four five six}

        @top            = Puppet::TransObject.new 'top', "class"
        @topobject      = Puppet::TransObject.new '/topobject', "file"
        @middle         = Puppet::TransObject.new 'middle', "class"
        @middleobject   = Puppet::TransObject.new '/middleobject', "file"
        @bottom         = Puppet::TransObject.new 'bottom', "class"
        @bottomobject   = Puppet::TransObject.new '/bottomobject', "file"

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
        @resources.each { |resource| @catalog.resource(resource.ref).should be_instance_of(Puppet::Type) }
    end

    it "should copy the tag list to the new catalog" do
        @catalog.tags.sort.should == @original.tags.sort
    end

    it "should copy the class list to the new catalog" do
        @catalog.classes.should == @original.classes
    end

    it "should duplicate the original edges" do
        @original.edges.each do |edge|
            @catalog.edge?(@catalog.resource(edge.source.ref), @catalog.resource(edge.target.ref)).should be_true
        end
    end

    it "should set itself as the catalog for each converted resource" do
        @catalog.vertices.each { |v| v.catalog.object_id.should equal(@catalog.object_id) }
    end

    it "should convert parser resources to transobjects and set the catalog" do
        catalog = Puppet::Node::Catalog.new("mynode")

        result = mock 'catalog'
        result.stub_everything

        Puppet::Node::Catalog.expects(:new).returns result

        trans = mock 'trans'
        resource = Puppet::Parser::Resource.new(:scope => mock("scope"), :source => mock("source"), :type => :file, :title => "/eh")
        resource.expects(:to_transobject).returns trans
        trans.expects(:catalog=).with result

        trans.stub_everything

        catalog.add_resource(resource)

        catalog.to_ral
    end

    # This tests #931.
    it "should not lose track of resources whose names vary" do
        changer = Puppet::TransObject.new 'changer', 'test'

        config = Puppet::Node::Catalog.new('test')
        config.add_resource(changer)
        config.add_resource(@top)

        config.add_edge(@top, changer)

        resource = stub 'resource', :name => "changer2", :title => "changer2", :ref => "Test[changer2]", :catalog= => nil, :remove => nil

        #changer is going to get duplicated as part of a fix for aliases 1094
        changer.expects(:dup).returns(changer)
        changer.expects(:to_type).returns(resource)

        newconfig = nil

        proc { @catalog = config.to_ral }.should_not raise_error
        @catalog.resource("Test[changer2]").should equal(resource)
    end

    after do
        # Remove all resource instances.
        @catalog.clear(true)
    end
end

describe Puppet::Node::Catalog, " when functioning as a resource container" do
    before do
        @catalog = Puppet::Node::Catalog.new("host")
        @one = stub 'resource1', :ref => "Me[one]", :catalog= => nil, :title => "one", :[] => "one"
        @two = stub 'resource2', :ref => "Me[two]", :catalog= => nil, :title => "two", :[] => "two"
        @dupe = stub 'resource3', :ref => "Me[one]", :catalog= => nil, :title => "one", :[] => "one"
    end

    it "should provide a method to add one or more resources" do
        @catalog.add_resource @one, @two
        @catalog.resource(@one.ref).should equal(@one)
        @catalog.resource(@two.ref).should equal(@two)
    end

    it "should set itself as the resource's catalog if it is not a relationship graph" do
        @one.expects(:catalog=).with(@catalog)
        @catalog.add_resource @one
    end

    it "should not set itself as the resource's catalog if it is a relationship graph" do
        @one.expects(:catalog=).never
        @catalog.is_relationship_graph = true
        @catalog.add_resource @one
    end

    it "should make all vertices available by resource reference" do
        @catalog.add_resource(@one)
        @catalog.resource(@one.ref).should equal(@one)
        @catalog.vertices.find { |r| r.ref == @one.ref }.should equal(@one)
    end

    it "should canonize how resources are referred to during retrieval when both type and title are provided" do
        @catalog.add_resource(@one)

        @catalog.resource("me", "one").should equal(@one)
    end

    it "should canonize how resources are referred to during retrieval when just the title is provided" do
        @catalog.add_resource(@one)

        @catalog.resource("me[one]", nil).should equal(@one)
    end

    it "should not allow two resources with the same resource reference" do
        @catalog.add_resource(@one)

        # These are used to build the failure
        @dupe.stubs(:file)
        @dupe.stubs(:line)
        @one.stubs(:file)
        @one.stubs(:line)
        proc { @catalog.add_resource(@dupe) }.should raise_error(ArgumentError)
    end

    it "should not store objects that do not respond to :ref" do
        proc { @catalog.add_resource("thing") }.should raise_error(ArgumentError)
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
        @catalog.resource(:schedule, "daily").should_not be_nil
    end
    
    it "should optionally support an initialization block and should finalize after such blocks" do
        @one.expects :finish
        @two.expects :finish
        config = Puppet::Node::Catalog.new("host") do |conf|
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
        @catalog.resource(@one.ref).should equal(@one)
    end

    it "should be able to find resources by reference or by type/title tuple" do
        @catalog.add_resource @one
        @catalog.resource("me", "one").should equal(@one)
    end

    it "should have a mechanism for removing resources" do
        @catalog.add_resource @one
        @one.expects :remove
        @catalog.remove_resource(@one)
        @catalog.resource(@one.ref).should be_nil
        @catalog.vertex?(@one).should be_false
    end

    it "should have a method for creating aliases for resources" do
        @catalog.add_resource @one
        @catalog.alias(@one, "other")
        @catalog.resource("me", "other").should equal(@one)
    end

    it "should ignore conflicting aliases that point to the aliased resource" do
        @catalog.alias(@one, "other")
        lambda { @catalog.alias(@one, "other") }.should_not raise_error
    end

    it "should create aliases for resources isomorphic resources whose names do not match their titles" do
        resource = Puppet::Type::File.create(:title => "testing", :path => "/something")

        @catalog.add_resource(resource)

        @catalog.resource(:file, "/something").should equal(resource)
    end

    it "should not create aliases for resources non-isomorphic resources whose names do not match their titles" do
        resource = Puppet::Type.type(:exec).create(:title => "testing", :command => "echo", :path => %w{/bin /usr/bin /usr/local/bin})

        @catalog.add_resource(resource)

        # Yay, I've already got a 'should' method
        @catalog.resource(:exec, "echo").object_id.should == nil.object_id
    end

    # This test is the same as the previous, but the behaviour should be explicit.
    it "should alias using the class name from the resource reference, not the resource class name" do
        @catalog.add_resource @one
        @catalog.alias(@one, "other")
        @catalog.resource("me", "other").should equal(@one)
    end

    it "should fail to add an alias if the aliased name already exists as a resource" do
        @catalog.add_resource @one
        proc { @catalog.alias @two, "one" }.should raise_error(ArgumentError)
    end

    it "should not fail when a resource has duplicate aliases created" do
        @catalog.add_resource @one
        proc { @catalog.alias @one, "one" }.should_not raise_error
    end

    it "should be able to look resources up by their aliases" do
        @catalog.add_resource @one
        @catalog.alias @one, "two"
        @catalog.resource(:me, "two").should equal(@one)
    end

    it "should remove resource aliases when the target resource is removed" do
        @catalog.add_resource @one
        @catalog.alias(@one, "other")
        @one.expects :remove
        @catalog.remove_resource(@one)
        @catalog.resource("me", "other").should be_nil
    end

    it "should add an alias for the namevar when the title and name differ on isomorphic resource types" do
        resource = Puppet::Type.type(:file).create :path => "/something", :title => "other", :content => "blah"
        resource.expects(:isomorphic?).returns(true)
        @catalog.add_resource(resource)
        @catalog.resource(:file, "other").should equal(resource)
        @catalog.resource(:file, "/something").ref.should == resource.ref
    end

    it "should not add an alias for the namevar when the title and name differ on non-isomorphic resource types" do
        resource = Puppet::Type.type(:file).create :path => "/something", :title => "other", :content => "blah"
        resource.expects(:isomorphic?).returns(false)
        @catalog.add_resource(resource)
        @catalog.resource(:file, resource.title).should equal(resource)
        # We can't use .should here, because the resources respond to that method.
        if @catalog.resource(:file, resource.name)
            raise "Aliased non-isomorphic resource"
        end
    end
end

describe Puppet::Node::Catalog do
    before :each do
        @catalog = Puppet::Node::Catalog.new("host")

        @catalog.retrieval_duration = Time.now
        @transaction = mock 'transaction'
        Puppet::Transaction.stubs(:new).returns(@transaction)
        @transaction.stubs(:evaluate)
        @transaction.stubs(:cleanup)
        @transaction.stubs(:addtimes)
    end

    describe Puppet::Node::Catalog, " when applying" do

        it "should create and evaluate a transaction" do
            @transaction.expects(:evaluate)
            @catalog.apply
        end

        it "should provide the catalog time to the transaction" do
            @transaction.expects(:addtimes).with do |arg|
                arg[:config_retrieval].should be_instance_of(Time)
                true
            end
            @catalog.apply
        end

        it "should clean up the transaction" do
            @transaction.expects :cleanup
            @catalog.apply
        end
    
        it "should return the transaction" do
            @catalog.apply.should equal(@transaction)
        end

        it "should yield the transaction if a block is provided" do
            @catalog.apply do |trans|
                trans.should equal(@transaction)
            end
        end
    
        it "should default to not being a host catalog" do
            @catalog.host_config.should be_nil
        end

        it "should pass supplied tags on to the transaction" do
            @transaction.expects(:tags=).with(%w{one two})
            @catalog.apply(:tags => %w{one two})
        end

        it "should set ignoreschedules on the transaction if specified in apply()" do
            @transaction.expects(:ignoreschedules=).with(true)
            @catalog.apply(:ignoreschedules => true)
        end
    end

    describe Puppet::Node::Catalog, " when applying host catalogs" do

        # super() doesn't work in the setup method for some reason
        before do
            @catalog.host_config = true
            Puppet::Util::Storage.stubs(:store)
        end

        it "should send a report if reporting is enabled" do
            Puppet[:report] = true
            @transaction.expects :send_report
            @transaction.stubs :any_failed? => false
            @catalog.apply
        end

        it "should send a report if report summaries are enabled" do
            Puppet[:summarize] = true
            @transaction.expects :send_report
            @transaction.stubs :any_failed? => false
            @catalog.apply
        end

        it "should initialize the state database before applying a catalog" do
            Puppet::Util::Storage.expects(:load)

            # Short-circuit the apply, so we know we're loading before the transaction
            Puppet::Transaction.expects(:new).raises ArgumentError
            proc { @catalog.apply }.should raise_error(ArgumentError)
        end

        it "should sync the state database after applying" do
            Puppet::Util::Storage.expects(:store)
            @transaction.stubs :any_failed? => false
            @catalog.apply
        end

        after { Puppet.settings.clear }
    end

    describe Puppet::Node::Catalog, " when applying non-host catalogs" do

        before do
            @catalog.host_config = false
        end
    
        it "should never send reports" do
            Puppet[:report] = true
            Puppet[:summarize] = true
            @transaction.expects(:send_report).never
            @catalog.apply
        end

        it "should never modify the state database" do
            Puppet::Util::Storage.expects(:load).never
            Puppet::Util::Storage.expects(:store).never
            @catalog.apply
        end

        after { Puppet.settings.clear }
    end
end

describe Puppet::Node::Catalog, " when creating a relationship graph" do
    before do
        Puppet::Type.type(:component)
        @catalog = Puppet::Node::Catalog.new("host")
        @compone = Puppet::Type::Component.create :name => "one"
        @comptwo = Puppet::Type::Component.create :name => "two", :require => ["class", "one"]
        @file = Puppet::Type.type(:file)
        @one = @file.create :path => "/one"
        @two = @file.create :path => "/two"
        @sub = @file.create :path => "/two/subdir"
        @catalog.add_edge @compone, @one
        @catalog.add_edge @comptwo, @two

        @three = @file.create :path => "/three"
        @four = @file.create :path => "/four", :require => ["file", "/three"]
        @five = @file.create :path => "/five"
        @catalog.add_resource @compone, @comptwo, @one, @two, @three, @four, @five, @sub
        @relationships = @catalog.relationship_graph
    end

    it "should fail when trying to create a relationship graph for a relationship graph" do
        proc { @relationships.relationship_graph }.should raise_error(Puppet::DevError)
    end

    it "should be able to create a relationship graph" do
        @relationships.should be_instance_of(Puppet::Node::Catalog)
    end

    it "should copy its host_config setting to the relationship graph" do
        config = Puppet::Node::Catalog.new
        config.host_config = true
        config.relationship_graph.host_config.should be_true
    end

    it "should not have any components" do
        @relationships.vertices.find { |r| r.instance_of?(Puppet::Type::Component) }.should be_nil
    end

    it "should have all non-component resources from the catalog" do
        # The failures print out too much info, so i just do a class comparison
        @relationships.vertex?(@five).should be_true
    end

    it "should have all resource relationships set as edges" do
        @relationships.edge?(@three, @four).should be_true
    end

    it "should copy component relationships to all contained resources" do
        @relationships.edge?(@one, @two).should be_true
    end

    it "should add automatic relationships to the relationship graph" do
        @relationships.edge?(@two, @sub).should be_true
    end

    it "should get removed when the catalog is cleaned up" do
        @relationships.expects(:clear).with(false)
        @catalog.clear
        @catalog.instance_variable_get("@relationship_graph").should be_nil
    end

    it "should create a new relationship graph after clearing the old one" do
        @relationships.expects(:clear).with(false)
        @catalog.clear
        @catalog.relationship_graph.should be_instance_of(Puppet::Node::Catalog)
    end

    it "should look up resources in the relationship graph if not found in the main catalog" do
        five = stub 'five', :ref => "File[five]", :catalog= => nil, :title => "five", :[] => "five"
        @relationships.add_resource five
        @catalog.resource(five.ref).should equal(five)
    end

    it "should provide a method to create additional resources that also registers the resource" do
        args = {:name => "/yay", :ensure => :file}
        resource = stub 'file', :ref => "File[/yay]", :catalog= => @catalog, :title => "/yay", :[] => "/yay"
        Puppet::Type.type(:file).expects(:create).with(args).returns(resource)
        @catalog.create_resource :file, args
        @catalog.resource("File[/yay]").should equal(resource)
    end

    it "should provide a mechanism for creating implicit resources" do
        args = {:name => "/yay", :ensure => :file}
        resource = stub 'file', :ref => "File[/yay]", :catalog= => @catalog, :title => "/yay", :[] => "/yay"
        Puppet::Type.type(:file).expects(:create).with(args).returns(resource)
        resource.expects(:implicit=).with(true)
        @catalog.create_implicit_resource :file, args
        @catalog.resource("File[/yay]").should equal(resource)
    end

    it "should add implicit resources to the relationship graph if there is one" do
        args = {:name => "/yay", :ensure => :file}
        resource = stub 'file', :ref => "File[/yay]", :catalog= => @catalog, :title => "/yay", :[] => "/yay"
        resource.expects(:implicit=).with(true)
        Puppet::Type.type(:file).expects(:create).with(args).returns(resource)
        # build the graph
        relgraph = @catalog.relationship_graph

        @catalog.create_implicit_resource :file, args
        relgraph.resource("File[/yay]").should equal(resource)
    end

    it "should remove resources created mid-transaction" do
        args = {:name => "/yay", :ensure => :file}
        resource = stub 'file', :ref => "File[/yay]", :catalog= => @catalog, :title => "/yay", :[] => "/yay"
        @transaction = mock 'transaction'
        Puppet::Transaction.stubs(:new).returns(@transaction)
        @transaction.stubs(:evaluate)
        @transaction.stubs(:cleanup)
        @transaction.stubs(:addtimes)
        Puppet::Type.type(:file).expects(:create).with(args).returns(resource)
        resource.expects :remove
        @catalog.apply do |trans|
            @catalog.create_resource :file, args
            @catalog.resource("File[/yay]").should equal(resource)
        end
        @catalog.resource("File[/yay]").should be_nil
    end

    it "should remove resources from the relationship graph if it exists" do
        @catalog.remove_resource(@one)
        @catalog.relationship_graph.vertex?(@one).should be_false
    end
end

describe Puppet::Node::Catalog, " when writing dot files" do
    before do
        @catalog = Puppet::Node::Catalog.new("host")
        @name = :test
        @file = File.join(Puppet[:graphdir], @name.to_s + ".dot")
    end
    it "should only write when it is a host catalog" do
        File.expects(:open).with(@file).never
        @catalog.host_config = false
        Puppet[:graph] = true
        @catalog.write_graph(@name)
    end

    it "should only write when graphing is enabled" do
        File.expects(:open).with(@file).never
        @catalog.host_config = true
        Puppet[:graph] = false
        @catalog.write_graph(@name)
    end

    it "should write a dot file based on the passed name" do
        File.expects(:open).with(@file, "w").yields(stub("file", :puts => nil))
        @catalog.expects(:to_dot).with("name" => @name.to_s.capitalize)
        @catalog.host_config = true
        Puppet[:graph] = true
        @catalog.write_graph(@name)
    end

    after do
        Puppet.settings.clear
    end
end

describe Puppet::Node::Catalog, " when indirecting" do
    before do
        @indirection = stub 'indirection', :name => :catalog

        Puppet::Util::Cacher.invalidate
    end

    it "should redirect to the indirection for retrieval" do
        Puppet::Node::Catalog.stubs(:indirection).returns(@indirection)
        @indirection.expects(:find)
        Puppet::Node::Catalog.find(:myconfig)
    end

    it "should default to the 'compiler' terminus" do
        Puppet::Node::Catalog.indirection.terminus_class.should == :compiler
    end

    after do
        Puppet::Util::Cacher.invalidate
    end
end

describe Puppet::Node::Catalog, " when converting to yaml" do
    before do
        @catalog = Puppet::Node::Catalog.new("me")
        @catalog.add_edge("one", "two")
    end

    it "should be able to be dumped to yaml" do
        YAML.dump(@catalog).should be_instance_of(String)
    end
end

describe Puppet::Node::Catalog, " when converting from yaml" do
    before do
        @catalog = Puppet::Node::Catalog.new("me")
        @catalog.add_edge("one", "two")

        text = YAML.dump(@catalog)
        @newcatalog = YAML.load(text)
    end

    it "should get converted back to a catalog" do
        @newcatalog.should be_instance_of(Puppet::Node::Catalog)
    end

    it "should have all vertices" do
        @newcatalog.vertex?("one").should be_true
        @newcatalog.vertex?("two").should be_true
    end

    it "should have all edges" do
        @newcatalog.edge?("one", "two").should be_true
    end
end
