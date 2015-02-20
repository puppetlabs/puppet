require 'spec_helper'
require 'hiera/backend/puppet_backend'
require 'hiera/scope'
require 'hiera/config'

describe Hiera::Backend::Puppet_backend do

  before do
    Hiera.stubs(:warn)
    Hiera.stubs(:debug)
    Hiera::Backend.stubs(:datasources).yields([])
    Puppet::Parser::Functions.stubs(:function).with(:include)

    @mockresource = mock
    @mockresource.stubs(:name).returns("ntp::config")

    @mockscope = mock
    @mockscope.stubs(:resource).returns(@mockresource)

    @scope = Hiera::Scope.new(@mockscope)

    @backend = Hiera::Backend::Puppet_backend.new
  end

  describe "#hierarchy" do
    it "should use the configured datasource" do
      with_config(:puppet => {:datasource => "rspec"},
                  :hierarchy => nil)

      @backend.hierarchy(@scope, nil).should == ["rspec::ntp::config", "rspec::ntp", "ntp::config::rspec", "ntp::rspec"]
    end

    it "should not include empty class names" do
      with_config(:puppet => {:datasource => "rspec"},
                  :hierarchy => ["%{foo}", "common"])

      @mockscope.expects(:lookupvar).at_least_once.with("foo").returns(nil)

      @backend.hierarchy(@scope, nil).should == ["rspec::common", "ntp::config::rspec", "ntp::rspec"]
    end

    it "should allow for an override data source" do
      with_config(:puppet => {:datasource => "rspec"},
                  :hierarchy => nil)

      @backend.hierarchy(@scope, "override").should == ["rspec::override", "rspec::ntp::config", "rspec::ntp", "ntp::config::rspec", "ntp::rspec"]
    end
  end

  describe "#lookup" do
    it "should attempt to load data from unincluded classes" do
      with_config(:puppet => {:datasource => "rspec"},
                  :hierarchy => ["rspec"])

      catalog = mock
      catalog.expects(:classes).returns([])

      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).with(["rspec::rspec"])
      @mockscope.expects(:lookupvar).with("rspec::rspec::key").returns("rspec")

      @backend.lookup("key", @scope, nil, nil).should == "rspec"
    end

    it "should not load loaded classes" do
      with_config(:puppet => {:datasource => "rspec"},
                  :hierarchy => ["rspec"])

      catalog = mock
      catalog.expects(:classes).returns(["rspec::rspec"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("rspec::rspec::key").returns("rspec")

      @backend.lookup("key", @scope, nil, nil).should == "rspec"
    end

    it "should return the first found data" do
      with_config(:puppet => {:datasource => "rspec"},
                  :hierarchy => ["override", "rspec"])

      catalog = mock
      catalog.expects(:classes).returns(["rspec::override", "override::override"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("rspec::override::key").returns("rspec")
      @mockscope.expects(:lookupvar).with("rspec::rspec::key").never

      @backend.lookup("key", @scope, "override", nil).should == "rspec"
    end

    it "should consider a value of false to be a real value" do
      with_config(:puppet => {:datasource => "rspec"},
                  :hierarchy => ["override", "rspec"])
      expected_answer = false

      catalog = mock
      catalog.expects(:classes).returns(["rspec::override", "override::override"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:lookupvar).with("rspec::override::key").returns(expected_answer)
      @mockscope.expects(:lookupvar).with("rspec::rspec::key").never

      @backend.lookup("key", @scope, "override", nil).should == expected_answer
    end

    it "should return an array of found data for array searches" do
      catalog = mock
      catalog.expects(:classes).returns(["rspec", "test"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("rspec::key").returns("rspec::key")
      @mockscope.expects(:lookupvar).with("test::key").returns("test::key")

      @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec", "test"])
      @backend.lookup("key", @scope, nil, :array).should == ["rspec::key", "test::key"]
    end

    it "should return a hash of found data for hash searches" do
      catalog = mock
      catalog.expects(:classes).returns(["rspec", "test"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("rspec::key").returns({'rspec'=>'key'})
      @mockscope.expects(:lookupvar).with("test::key").returns({'test'=>'key'})

      @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec", "test"])
      @backend.lookup("key", @scope, nil, :hash).should == {'rspec'=>'key', 'test'=>'key'}
    end

    it "should return a merged hash of found data for hash searches" do
      catalog = mock
      catalog.expects(:classes).returns(["rspec", "test"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("rspec::key").returns({'rspec'=>'key', 'common'=>'rspec'})
      @mockscope.expects(:lookupvar).with("test::key").returns({'test'=>'key', 'common'=>'rspec'})

      @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec", "test"])
      @backend.lookup("key", @scope, nil, :hash).should == {'rspec'=>'key', 'common'=>'rspec', 'test'=>'key'}
    end
  end

  def with_config(config)
    config.each do |key, value|
      Hiera::Config.expects("[]").with(key).returns(value)
    end
  end
end
