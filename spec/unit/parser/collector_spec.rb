#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/rails'
require 'puppet/parser/collector'

describe Puppet::Parser::Collector, "when initializing" do
  before do
    @scope = mock 'scope'
    @resource_type = 'resource_type'
    @form = :exported
    @vquery = mock 'vquery'
    @equery = mock 'equery'

    @collector = Puppet::Parser::Collector.new(@scope, @resource_type, @equery, @vquery, @form)
  end

  it "should require a scope" do
    @collector.scope.should equal(@scope)
  end

  it "should require a resource type" do
    @collector.type.should == 'Resource_type'
  end

  it "should only accept :virtual or :exported as the collector form" do
    expect { @collector = Puppet::Parser::Collector.new(@scope, @resource_type, @vquery, @equery, :other) }.to raise_error(ArgumentError)
  end

  it "should accept an optional virtual query" do
    @collector.vquery.should equal(@vquery)
  end

  it "should accept an optional exported query" do
    @collector.equery.should equal(@equery)
  end

  it "should canonicalize the type name" do
    @collector = Puppet::Parser::Collector.new(@scope, "resource::type", @equery, @vquery, @form)
    @collector.type.should == "Resource::Type"
  end

  it "should accept an optional resource override" do
    @collector = Puppet::Parser::Collector.new(@scope, "resource::type", @equery, @vquery, @form)
    override = { :parameters => "whatever" }
    @collector.add_override(override)
    @collector.overrides.should equal(override)
  end

end

describe Puppet::Parser::Collector, "when collecting specific virtual resources" do
  before do
    @scope = mock 'scope'
    @vquery = mock 'vquery'
    @equery = mock 'equery'
    @compiler = mock 'compiler'

    @collector = Puppet::Parser::Collector.new(@scope, "resource_type", @equery, @vquery, :virtual)
  end

  it "should not fail when it does not find any resources to collect" do
    @collector.resources = ["File[virtual1]", "File[virtual2]"]
    @scope.stubs(:findresource).returns(false)
    expect { @collector.evaluate }.to_not raise_error
  end

  it "should mark matched resources as non-virtual" do
    @collector.resources = ["File[virtual1]", "File[virtual2]"]
    one = stub_everything 'one'
    one.expects(:virtual=).with(false)

    @scope.stubs(:findresource).with("File[virtual1]").returns(one)
    @scope.stubs(:findresource).with("File[virtual2]").returns(nil)
    @collector.evaluate
  end

  it "should return matched resources" do
    @collector.resources = ["File[virtual1]", "File[virtual2]"]
    one = stub_everything 'one'
    @scope.stubs(:findresource).with("File[virtual1]").returns(one)
    @scope.stubs(:findresource).with("File[virtual2]").returns(nil)
    @collector.evaluate.should == [one]
  end

  it "should delete itself from the compile's collection list if it has found all of its resources" do
    @collector.resources = ["File[virtual1]"]
    one = stub_everything 'one'
    @compiler.expects(:delete_collection).with(@collector)
    @scope.expects(:compiler).returns(@compiler)
    @scope.stubs(:findresource).with("File[virtual1]").returns(one)
    @collector.evaluate
  end

  it "should not delete itself from the compile's collection list if it has unfound resources" do
    @collector.resources = ["File[virtual1]"]
    one = stub_everything 'one'
    @compiler.expects(:delete_collection).never
    @scope.stubs(:findresource).with("File[virtual1]").returns(nil)
    @collector.evaluate
  end
end

describe Puppet::Parser::Collector, "when collecting virtual and catalog resources" do
  before do
    @scope = mock 'scope'
    @compiler = mock 'compile'
    @scope.stubs(:compiler).returns(@compiler)
    @resource_type = "Mytype"
    @vquery = proc { |res| true }

    @collector = Puppet::Parser::Collector.new(@scope, @resource_type, nil, @vquery, :virtual)
  end

  it "should find all virtual resources matching the vquery" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true
    two = stub_everything 'two', :type => "Mytype", :virtual? => true

    @compiler.expects(:resources).returns([one, two])

    @collector.evaluate.should == [one, two]
  end

  it "should find all non-virtual resources matching the vquery" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => false
    two = stub_everything 'two', :type => "Mytype", :virtual? => false

    @compiler.expects(:resources).returns([one, two])

    @collector.evaluate.should == [one, two]
  end

  it "should mark all matched resources as non-virtual" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true

    one.expects(:virtual=).with(false)

    @compiler.expects(:resources).returns([one])

    @collector.evaluate
  end

  it "should return matched resources" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true
    two = stub_everything 'two', :type => "Mytype", :virtual? => true

    @compiler.expects(:resources).returns([one, two])

    @collector.evaluate.should == [one, two]
  end

  it "should return all resources of the correct type if there is no virtual query" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true
    two = stub_everything 'two', :type => "Mytype", :virtual? => true

    one.expects(:virtual=).with(false)
    two.expects(:virtual=).with(false)

    @compiler.expects(:resources).returns([one, two])

    @collector = Puppet::Parser::Collector.new(@scope, @resource_type, nil, nil, :virtual)

    @collector.evaluate.should == [one, two]
  end

  it "should not return or mark resources of a different type" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true
    two = stub_everything 'two', :type => :other, :virtual? => true

    one.expects(:virtual=).with(false)
    two.expects(:virtual=).never

    @compiler.expects(:resources).returns([one, two])

    @collector.evaluate.should == [one]
  end

  it "should create a resource with overridden parameters" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true, :title => "test"
    param = stub 'param'
    @compiler.stubs(:add_override)

    @compiler.expects(:resources).returns([one])

    @collector.add_override(:parameters => param )
    Puppet::Parser::Resource.expects(:new).with { |type, title, h|
      h[:parameters] == param
    }

    @collector.evaluate
  end

  it "should define a new allow all child_of? on overriden resource" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true, :title => "test"
    param = stub 'param'
    source = stub 'source'
    @compiler.stubs(:add_override)

    @compiler.expects(:resources).returns([one])

    @collector.add_override(:parameters => param, :source => source )
    Puppet::Parser::Resource.stubs(:new)

    source.expects(:meta_def).with { |name,block| name == :child_of? }

    @collector.evaluate
  end


  it "should not override already overriden resources for this same collection in a previous run" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true, :title => "test"
    param = stub 'param'
    @compiler.stubs(:add_override)

    @compiler.expects(:resources).at_least(2).returns([one])

    @collector.add_override(:parameters => param )
    Puppet::Parser::Resource.expects(:new).once.with { |type, title, h|
      h[:parameters] == param
    }

    @collector.evaluate

    @collector.evaluate
  end

  it "should not return resources that were collected in a previous run of this collector" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true, :title => "test"
    @compiler.stubs(:resources).returns([one])

    @collector.evaluate

    @collector.evaluate.should be_false
  end


  it "should tell the compiler about the overriden resources" do
    one = stub_everything 'one', :type => "Mytype", :virtual? => true, :title => "test"
    param = stub 'param'

    one.expects(:virtual=).with(false)
    @compiler.expects(:resources).returns([one])
    @collector.add_override(:parameters => param )
    Puppet::Parser::Resource.stubs(:new).returns("whatever")

    @compiler.expects(:add_override).with("whatever")

    @collector.evaluate
  end

  it "should not return or mark non-matching resources" do
    @collector.vquery = proc { |res| res.name == :one }

    one = stub_everything 'one', :name => :one, :type => "Mytype", :virtual? => true
    two = stub_everything 'two', :name => :two, :type => "Mytype", :virtual? => true

    one.expects(:virtual=).with(false)
    two.expects(:virtual=).never

    @compiler.expects(:resources).returns([one, two])

    @collector.evaluate.should == [one]
  end
end

describe Puppet::Parser::Collector, "when collecting exported resources", :if => can_use_scratch_database? do
  include PuppetSpec::Files

  before do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    @scope = Puppet::Parser::Scope.new @compiler
    @resource_type = "notify"
    @equery = ["title", "!=", ""]
    @vquery = proc { |r| true }
    @collector = Puppet::Parser::Collector.new(@scope, @resource_type,
                                               @equery, @vquery, :exported)
  end

  it "should just return false if :storeconfigs is not enabled" do
    Puppet[:storeconfigs] = false
    @collector.evaluate.should be_false
  end

  context "with storeconfigs enabled" do
    before :each do
      setup_scratch_database
      Puppet[:storeconfigs] = true
      Puppet[:environment]  = "production"
      Puppet[:storeconfigs_backend] = "active_record"
    end

    after :each do
      Puppet::Rails.teardown
    end

    it "should return all matching resources from the current compile and mark them non-virtual and non-exported" do
      one = Puppet::Parser::Resource.new('notify', 'one',
                                         :virtual  => true,
                                         :exported => true,
                                         :scope    => @scope)
      two = Puppet::Parser::Resource.new('notify', 'two',
                                         :virtual  => true,
                                         :exported => true,
                                         :scope    => @scope)

      @compiler.resources << one
      @compiler.resources << two

      @collector.evaluate.should == [one, two]
      one.should_not be_virtual
      two.should_not be_virtual
    end

    it "should mark all returned resources as not virtual" do
      one = Puppet::Parser::Resource.new('notify', 'one',
                                         :virtual  => true,
                                         :exported => true,
                                         :scope    => @scope)

      @compiler.resources << one

      @collector.evaluate.should == [one]
      one.should_not be_virtual
    end

    it "should convert all found resources into parser resources if necessary" do
      host = Puppet::Rails::Host.create!(:name => 'one.local')
      Puppet::Rails::Resource.
        create!(:host     => host,
                :restype  => 'Notify', :title => 'whammo',
                :exported => true)

      result = @collector.evaluate
      result.length.should == 1
      result.first.should be_an_instance_of Puppet::Parser::Resource
      result.first.type.should == 'Notify'
      result.first.title.should == 'whammo'
    end

    it "should leave parser resources alone" do
      resource = Puppet::Parser::Resource.new(:file, "/tmp/foo", :scope => @scope)
      resource2 = Puppet::Parser::Resource.new(:file, "/tmp/bar", :scope => @scope)
      resource.expects(:to_resource).never
      resource2.expects(:to_resource).never

      resources = [resource, resource2]

      Puppet::Resource.indirection.stubs(:search).returns resources

      @collector.evaluate.should == resources
    end

    it "should override all exported collected resources if collector has an override" do
      host = Puppet::Rails::Host.create!(:name => 'one.local')
      Puppet::Rails::Resource.
        create!(:host     => host,
                :restype  => 'Notify', :title => 'whammo',
                :exported => true)

      param = Puppet::Parser::Resource::Param.
        new(:name => 'message', :value => 'howdy')
      @collector.add_override(:parameters => [param], :scope => @scope)

      got = @collector.evaluate
      got.first[:message].should == param.value
    end

    it "should store converted resources in the compile's resource list" do
      host = Puppet::Rails::Host.create!(:name => 'one.local')
      Puppet::Rails::Resource.
        create!(:host     => host,
                :restype  => 'Notify', :title => 'whammo',
                :exported => true)

      @compiler.expects(:add_resource).with do |scope, resource|
        scope.should be_an_instance_of Puppet::Parser::Scope
        resource.type.should  == 'Notify'
        resource.title.should == 'whammo'
        true
      end

      @collector.evaluate
    end

    # This way one host doesn't store another host's resources as exported.
    it "should mark resources collected from the database as not exported" do
      host = Puppet::Rails::Host.create!(:name => 'one.local')
      Puppet::Rails::Resource.
        create!(:host     => host,
                :restype  => 'Notify', :title => 'whammo',
                :exported => true)

      got = @collector.evaluate
      got.length.should == 1
      got.first.type.should == "Notify"
      got.first.title.should == "whammo"
      got.first.should_not be_exported
    end

    it "should fail if an equivalent resource already exists in the compile" do
      host = Puppet::Rails::Host.create!(:name => 'one.local')
      Puppet::Rails::Resource.
        create!(:host     => host,
                :restype  => 'Notify', :title => 'whammo',
                :exported => true)

      local = Puppet::Parser::Resource.new('notify', 'whammo', :scope => @scope)
      @compiler.add_resource(@scope, local)

      expect { @collector.evaluate }.
        to raise_error Puppet::ParseError, /A duplicate resource was found while collecting exported resources/
    end

    it "should ignore exported resources that match already-collected resources" do
      host = Puppet::Rails::Host.create!(:name => 'one.local')
      # One that we already collected...
      db = Puppet::Rails::Resource.
        create!(:host     => host,
                :restype  => 'Notify', :title => 'whammo',
                :exported => true)
      # ...and one we didn't.
      Puppet::Rails::Resource.
        create!(:host     => host,
                :restype  => 'Notify', :title => 'boingy-boingy',
                :exported => true)

      local = Puppet::Parser::Resource.new('notify', 'whammo',
                                           :scope        => @scope,
                                           :collector_id => db.id)
      @compiler.add_resource(@scope, local)

      got = nil
      expect { got = @collector.evaluate }.not_to raise_error
      got.length.should == 1
      got.first.type.should == "Notify"
      got.first.title.should == "boingy-boingy"
    end
  end
end
