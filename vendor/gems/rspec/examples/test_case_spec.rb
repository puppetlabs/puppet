require File.dirname(__FILE__) + '/spec_helper'
require 'test/unit'

class RSpecIntegrationTest < Test::Unit::TestCase
  def self.fixtures(*args)
    @@fixtures = true
  end
  
  def self.verify_class_method
    @@fixtures.should == true
  end
  
  def setup
    @test_case_setup_called = true
  end

  def teardown
    @test_case_teardown_called = true
  end

  def run(result)
  end

  def helper_method
    @helper_method_called = true
  end
end

module RandomHelperModule
  def random_task
    @random_task_called = true
  end
end

describe "RSpec should integrate with Test::Unit::TestCase" do
  inherit RSpecIntegrationTest
  include RandomHelperModule
  
  fixtures :some_table

  prepend_before(:each) {setup}

  before(:each) do
    @rspec_setup_called = true
  end

  it "TestCase#setup should be called." do
    @test_case_setup_called.should be_true
    @rspec_setup_called.should be_true
  end

  it "RSpec should be able to access TestCase methods" do
    helper_method
    @helper_method_called.should be_true
  end

  it "RSpec should be able to accept included modules" do
    random_task
    @random_task_called.should be_true
  end
  
  after(:each) do
    RSpecIntegrationTest.verify_class_method
  end
end
