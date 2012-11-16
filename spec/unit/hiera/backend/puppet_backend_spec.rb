require 'spec_helper'
require 'hiera/backend/puppet_backend'
require 'hiera/scope'

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
      Hiera::Config.expects("[]").with(:puppet).returns({:datasource => "rspec"})
      Hiera::Config.expects("[]").with(:hierarchy)

      ["ntp", "ntp::config"].each do |klass|
        Hiera::Backend.expects(:parse_string).with(klass, @scope, {"calling_module" => "ntp", "calling_class" => "ntp::config"}).returns(klass)
      end

      @backend.hierarchy(@scope, nil).should == ["rspec::ntp::config", "rspec::ntp", "ntp::config::rspec", "ntp::rspec"]
    end

    it "should not include empty class names" do
      Hiera::Config.expects("[]").with(:puppet).returns({:datasource => "rspec"})
      Hiera::Config.expects("[]").with(:hierarchy).returns(["%{foo}", "common"])

      Hiera::Backend.expects(:parse_string).with("common", @scope, {"calling_module" => "ntp", "calling_class" => "ntp::config"}).returns("common")
      Hiera::Backend.expects(:parse_string).with("%{foo}", @scope, {"calling_module" => "ntp", "calling_class" => "ntp::config"}).returns("")

      @backend.hierarchy(@scope, nil).should == ["rspec::common", "ntp::config::rspec", "ntp::rspec"]
    end

    it "should allow for an override data source" do
      Hiera::Config.expects("[]").with(:puppet).returns({:datasource => "rspec"})
      Hiera::Config.expects("[]").with(:hierarchy)

      ["ntp", "ntp::config"].each do |klass|
        Hiera::Backend.expects(:parse_string).with(klass, @scope, {"calling_module" => "ntp", "calling_class" => "ntp::config"}).returns(klass)
      end

      @backend.hierarchy(@scope, "override").should == ["rspec::override", "rspec::ntp::config", "rspec::ntp", "ntp::config::rspec", "ntp::rspec"]
    end
  end

  describe "#lookup" do
    it "should attempt to load data from unincluded classes" do
      Hiera::Backend.expects(:parse_answer).with("rspec", @scope).returns("rspec")

      catalog = mock
      catalog.expects(:classes).returns([])

      @scope.expects(:catalog).returns(catalog)
      @scope.expects(:function_include).with(["rspec"])
      @mockscope.expects(:lookupvar).with("rspec::key").returns("rspec")

      @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec"])
      @backend.lookup("key", @scope, nil, nil).should == "rspec"
    end

    it "should not load loaded classes" do
      Hiera::Backend.expects(:parse_answer).with("rspec", @scope).returns("rspec")
      catalog = mock
      catalog.expects(:classes).returns(["rspec"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("rspec::key").returns("rspec")

      @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec"])
      @backend.lookup("key", @scope, nil, nil).should == "rspec"
    end

    it "should return the first found data" do
      Hiera::Backend.expects(:parse_answer).with("rspec", @scope).returns("rspec")
      catalog = mock
      catalog.expects(:classes).returns(["rspec", "override"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("override::key").returns("rspec")
      @mockscope.expects(:lookupvar).with("rspec::key").never

      @backend.expects(:hierarchy).with(@scope, "override").returns(["override", "rspec"])
      @backend.lookup("key", @scope, "override", nil).should == "rspec"
    end

    it "should consider a value of false to be a real value" do
      expected_answer = false

      Hiera::Backend.expects(:parse_answer).with(expected_answer, @scope).returns(expected_answer)
      catalog = mock
      catalog.expects(:classes).returns(["rspec", "override"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:lookupvar).with("override::key").returns(expected_answer)
      @mockscope.expects(:lookupvar).with("rspec::key").never
      @backend.expects(:hierarchy).with(@scope, "override").returns(["override", "rspec"])

      @backend.lookup("key", @scope, "override", nil).should == expected_answer
    end

    it "should return an array of found data for array searches" do
      Hiera::Backend.expects(:parse_answer).with("rspec::key", @scope).returns("rspec::key")
      Hiera::Backend.expects(:parse_answer).with("test::key", @scope).returns("test::key")
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
      Hiera::Backend.expects(:parse_answer).with("rspec::key", @scope).returns({'rspec'=>'key'})
      Hiera::Backend.expects(:parse_answer).with("test::key", @scope).returns({'test'=>'key'})
      catalog = mock
      catalog.expects(:classes).returns(["rspec", "test"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("rspec::key").returns("rspec::key")
      @mockscope.expects(:lookupvar).with("test::key").returns("test::key")

      @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec", "test"])
      @backend.lookup("key", @scope, nil, :hash).should == {'rspec'=>'key', 'test'=>'key'}
    end

    it "should return a merged hash of found data for hash searches" do
      Hiera::Backend.expects(:parse_answer).with("rspec::key", @scope).returns({'rspec'=>'key', 'common'=>'rspec'})
      Hiera::Backend.expects(:parse_answer).with("test::key", @scope).returns({'test'=>'key', 'common'=>'rspec'})
      catalog = mock
      catalog.expects(:classes).returns(["rspec", "test"])
      @mockscope.expects(:catalog).returns(catalog)
      @mockscope.expects(:function_include).never
      @mockscope.expects(:lookupvar).with("rspec::key").returns("rspec::key")
      @mockscope.expects(:lookupvar).with("test::key").returns("test::key")

      @backend.expects(:hierarchy).with(@scope, nil).returns(["rspec", "test"])
      @backend.lookup("key", @scope, nil, :hash).should == {'rspec'=>'key', 'common'=>'rspec', 'test'=>'key'}
    end
  end
end
