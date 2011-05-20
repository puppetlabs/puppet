#!/usr/bin/env rspec
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
    proc { @collector = Puppet::Parser::Collector.new(@scope, @resource_type, @vquery, @equery, :other) }.should raise_error(ArgumentError)
  end

  it "should accept an optional virtual query" do
    @collector.vquery.should equal(@vquery)
  end

  it "should accept an optional exported query" do
    @collector.equery.should equal(@equery)
  end

  it "should canonize the type name" do
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

    @collector = Puppet::Parser::Collector.new(@scope, "resource_type", @equery, @vquery, :virtual)
  end

  it "should not fail when it does not find any resources to collect" do
    @collector.resources = ["File[virtual1]", "File[virtual2]"]
    @scope.stubs(:findresource).returns(false)
    proc { @collector.evaluate }.should_not raise_error
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

describe Puppet::Parser::Collector, "when collecting exported resources", :if => Puppet.features.rails? do
  before do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    @scope = Puppet::Parser::Scope.new :compiler => @compiler
    @resource_type = "Mytype"
    @equery = "test = true"
    @vquery = proc { |r| true }

    res = stub("resource 1")
    res.stubs(:type).returns @resource_type
    Puppet::Resource.stubs(:new).returns res

    Puppet.settings.stubs(:value).with(:storeconfigs).returns true
    Puppet.settings.stubs(:value).with(:environment).returns "production"

    @collector = Puppet::Parser::Collector.new(@scope, @resource_type, @equery, @vquery, :exported)
  end

  # Stub most of our interface to Rails.
  def stub_rails(everything = false)
    ActiveRecord::Base.stubs(:connected?).returns(false)
    Puppet::Rails.stubs(:init)
    if everything
      Puppet::Rails::Host.stubs(:find_by_name).returns(nil)
      Puppet::Rails::Resource.stubs(:find).returns([])
    end
  end

  it "should just return false if :storeconfigs is not enabled" do
    Puppet.settings.expects(:value).with(:storeconfigs).returns false
    @collector.evaluate.should be_false
  end

  it "should use initialize the Rails support if ActiveRecord is not connected" do
    @compiler.stubs(:resources).returns([])
    ActiveRecord::Base.expects(:connected?).returns(false)
    Puppet::Rails.expects(:init)
    Puppet::Rails::Host.stubs(:find_by_name).returns(nil)
    Puppet::Rails::Resource.stubs(:find).returns([])

    @collector.evaluate
  end

  it "should return all matching resources from the current compile and mark them non-virtual and non-exported" do
    stub_rails(true)

    one = stub 'one', :type => "Mytype", :virtual? => true, :exported? => true, :ref => "one"
    two = stub 'two', :type => "Mytype", :virtual? => true, :exported? => true, :ref => "two"

    one.stubs(:exported=)
    one.stubs(:virtual=)
    two.stubs(:exported=)
    two.stubs(:virtual=)

    @compiler.expects(:resources).returns([one, two])

    @collector.evaluate.should == [one, two]
  end

  it "should mark all returned resources as not virtual" do
    stub_rails(true)

    one = stub 'one', :type => "Mytype", :virtual? => true, :exported? => true, :ref => "one"

    one.stubs(:exported=)
    one.expects(:virtual=).with(false)

    @compiler.expects(:resources).returns([one])

    @collector.evaluate.should == [one]
  end

  it "should convert all found resources into parser resources" do
    stub_rails
    Puppet::Rails::Host.stubs(:find_by_name).returns(nil)

    one = stub 'one', :restype => "Mytype", :title => "one", :virtual? => true, :exported? => true, :ref => "one"
    Puppet::Rails::Resource.stubs(:find).returns([one])

    resource = mock 'resource'
    one.expects(:to_resource).with(@scope).returns(resource)
    resource.stubs(:exported=)
    resource.stubs(:virtual=)
    resource.stubs(:ref)

    @compiler.stubs(:resources).returns([])
    @scope.stubs(:findresource).returns(nil)

    @compiler.stubs(:add_resource)

    @collector.evaluate.should == [resource]
  end

  it "should override all exported collected resources if collector has an override" do
    stub_rails
    Puppet::Rails::Host.stubs(:find_by_name).returns(nil)

    one = stub 'one', :restype => "Mytype", :title => "one", :virtual? => true, :exported? => true, :ref => "one"
    Puppet::Rails::Resource.stubs(:find).returns([one])

    resource = mock 'resource', :type => "Mytype"
    one.expects(:to_resource).with(@scope).returns(resource)
    resource.stubs(:exported=)
    resource.stubs(:virtual=)
    resource.stubs(:ref)
    resource.stubs(:title)

    @compiler.stubs(:resources).returns([])
    @scope.stubs(:findresource).returns(nil)

    param = stub 'param'
    @compiler.stubs(:add_override)
    @compiler.stubs(:add_resource)

    @collector.add_override(:parameters => param )
    Puppet::Parser::Resource.expects(:new).once.with { |type, title, h|
      h[:parameters] == param
    }

    @collector.evaluate
  end

  it "should store converted resources in the compile's resource list" do
    stub_rails
    Puppet::Rails::Host.stubs(:find_by_name).returns(nil)

    one = stub 'one', :restype => "Mytype", :title => "one", :virtual? => true, :exported? => true, :ref => "one"
    Puppet::Rails::Resource.stubs(:find).returns([one])

    resource = mock 'resource'
    one.expects(:to_resource).with(@scope).returns(resource)
    resource.stubs(:exported=)
    resource.stubs(:virtual=)
    resource.stubs(:ref)

    @compiler.stubs(:resources).returns([])
    @scope.stubs(:findresource).returns(nil)

    @compiler.expects(:add_resource).with(@scope, resource)

    @collector.evaluate.should == [resource]
  end

  # This way one host doesn't store another host's resources as exported.
  it "should mark resources collected from the database as not exported" do
    stub_rails
    Puppet::Rails::Host.stubs(:find_by_name).returns(nil)

    one = stub 'one', :restype => "Mytype", :title => "one", :virtual? => true, :exported? => true, :ref => "one"
    Puppet::Rails::Resource.stubs(:find).returns([one])

    resource = mock 'resource'
    one.expects(:to_resource).with(@scope).returns(resource)
    resource.expects(:exported=).with(false)
    resource.stubs(:virtual=)
    resource.stubs(:ref)

    @compiler.stubs(:resources).returns([])
    @scope.stubs(:findresource).returns(nil)

    @compiler.stubs(:add_resource)

    @collector.evaluate
  end

  it "should fail if an equivalent resource already exists in the compile" do
    stub_rails
    Puppet::Rails::Host.stubs(:find_by_name).returns(nil)

    rails = stub 'one', :restype => "Mytype", :title => "one", :virtual? => true, :exported? => true, :id => 1, :ref => "yay"
    inmemory = stub 'one', :type => "Mytype", :virtual? => true, :exported? => true, :rails_id => 2

    Puppet::Rails::Resource.stubs(:find).returns([rails])

    resource = mock 'resource'

    @compiler.stubs(:resources).returns([])
    @scope.stubs(:findresource).returns(inmemory)

    @compiler.stubs(:add_resource)

    proc { @collector.evaluate }.should raise_error(Puppet::ParseError)
  end

  it "should ignore exported resources that match already-collected resources" do
    stub_rails
    Puppet::Rails::Host.stubs(:find_by_name).returns(nil)

    rails = stub 'one', :restype => "Mytype", :title => "one", :virtual? => true, :exported? => true, :id => 1, :ref => "yay"
    inmemory = stub 'one', :type => "Mytype", :virtual? => true, :exported? => true, :rails_id => 1

    Puppet::Rails::Resource.stubs(:find).returns([rails])

    resource = mock 'resource'

    @compiler.stubs(:resources).returns([])
    @scope.stubs(:findresource).returns(inmemory)

    @compiler.stubs(:add_resource)

    proc { @collector.evaluate }.should_not raise_error(Puppet::ParseError)
  end
end

describe Puppet::Parser::Collector, "when building its ActiveRecord query for collecting exported resources", :if => Puppet.features.rails? do
  before do
    @scope = stub 'scope', :host => "myhost", :debug => nil
    @compiler = mock 'compile'
    @scope.stubs(:compiler).returns(@compiler)
    @resource_type = "Mytype"
    @equery = nil
    @vquery = proc { |r| true }

    @resource = stub_everything 'collected'

    @collector = Puppet::Parser::Collector.new(@scope, @resource_type, @equery, @vquery, :exported)
    @collector.stubs(:exported_resource).with(@resource).returns(@resource)
    @compiler.stubs(:resources).returns([])

    ActiveRecord::Base.stubs(:connected?).returns(false)

    Puppet::Rails.stubs(:init)
    Puppet::Rails::Host.stubs(:find_by_name).returns(nil)
    Puppet::Rails::Resource.stubs(:find).returns([])

    Puppet.settings.stubs(:value).with(:storeconfigs).returns true
  end

  it "should exclude all resources from the host if ActiveRecord contains information for this host" do
    @host = mock 'host'
    @host.stubs(:id).returns 5

    Puppet::Rails::Host.expects(:find_by_name).with(@scope.host).returns(@host)

    Puppet::Rails::Resource.stubs(:find).with { |*arguments|
      options = arguments[1]
      options[:conditions][0] =~ /^host_id != \?/ and options[:conditions][1] == 5
    }.returns([@resource])

    @collector.evaluate.should == [@resource]
  end

  it "should join with parameter names, parameter values when querying ActiveRecord" do
    @collector.equery = "param_names.name = title"
    Puppet::Rails::Resource.stubs(:find).with { |*arguments|
      options = arguments[1]
      options[:joins] == {:param_values => :param_name}
    }.returns([@resource])

    @collector.evaluate.should == [@resource]
  end

  it "should join with tag tables when querying ActiveRecord with a tag exported query" do
    @collector.equery = "puppet_tags.name = test"
    Puppet::Rails::Resource.stubs(:find).with { |*arguments|
      options = arguments[1]
      options[:joins] == {:resource_tags => :puppet_tag}
    }.returns([@resource])

    @collector.evaluate.should == [@resource]
  end

  it "should not join parameters when querying ActiveRecord with a tag exported query" do
    @collector.equery = "puppet_tags.name = test"
    Puppet::Rails::Resource.stubs(:find).with { |*arguments|
      options = arguments[1]
      options[:joins] == {:param_values => :param_name}
    }.returns([@resource])

    @collector.evaluate.should be_false
  end

  it "should only search for exported resources with the matching type" do
    Puppet::Rails::Resource.stubs(:find).with { |*arguments|
      options = arguments[1]
      options[:conditions][0].include?("(exported=? AND restype=?)") and options[:conditions][1] == true and options[:conditions][2] == "Mytype"
    }.returns([@resource])

    @collector.evaluate.should == [@resource]
  end

  it "should include the export query if one is provided" do
    @collector.equery = "test = true"
    Puppet::Rails::Resource.stubs(:find).with { |*arguments|
      options = arguments[1]
      options[:conditions][0].include?("test = true")
    }.returns([@resource])

    @collector.evaluate.should == [@resource]
  end
end
