#! /usr/bin/env ruby

require 'spec_helper'

require 'puppet/util/instrumentation'
require 'puppet/util/instrumentation/instrumentable'

describe Puppet::Util::Instrumentation::Instrumentable::Probe do

  before(:each) do
    Puppet::Util::Instrumentation.stubs(:start)
    Puppet::Util::Instrumentation.stubs(:stop)

    class ProbeTest
      def mymethod(arg1, arg2, arg3)
        :it_worked
      end
    end
  end

  after(:each) do
    if ProbeTest.method_defined?(:instrumented_mymethod)
      ProbeTest.class_eval {
        remove_method(:mymethod)
        alias_method(:mymethod, :instrumented_mymethod)
      }
    end
    Puppet::Util::Instrumentation::Instrumentable.clear_probes
  end

  describe "when enabling a probe" do
    it "should raise an error if the probe is already enabled" do
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      probe.enable
      lambda { probe.enable }.should raise_error
    end

    it "should rename the original method name" do
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      probe.enable
      ProbeTest.new.should respond_to(:instrumented_mymethod)
    end

    it "should create a new method of the original name" do
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      probe.enable
      ProbeTest.new.should respond_to(:mymethod)
    end
  end

  describe "when disabling a probe" do
    it "should raise an error if the probe is already enabled" do
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      lambda { probe.disable }.should raise_error
    end

    it "should rename the original method name" do
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      probe.enable
      probe.disable

      Puppet::Util::Instrumentation.expects(:start).never
      Puppet::Util::Instrumentation.expects(:stop).never
      ProbeTest.new.mymethod(1,2,3).should == :it_worked
    end

    it "should remove the created method" do
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      probe.enable
      probe.disable
      ProbeTest.new.should_not respond_to(:instrumented_mymethod)
    end
  end

  describe "when a probe is called" do
    it "should call the original method" do
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      probe.enable
      test = ProbeTest.new
      test.expects(:instrumented_mymethod).with(1,2,3)
      test.mymethod(1,2,3)
    end

    it "should start the instrumentation" do
      Puppet::Util::Instrumentation.expects(:start)
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      probe.enable
      test = ProbeTest.new
      test.mymethod(1,2,3)
    end

    it "should stop the instrumentation" do
      Puppet::Util::Instrumentation.expects(:stop)
      probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
      probe.enable
      test = ProbeTest.new
      test.mymethod(1,2,3)
    end

    describe "and the original method raises an exception" do
      it "should propagate the exception" do
        probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
        probe.enable
        test = ProbeTest.new
        test.expects(:instrumented_mymethod).with(1,2,3).raises
        lambda { test.mymethod(1,2,3) }.should raise_error
      end

      it "should stop the instrumentation" do
        Puppet::Util::Instrumentation.expects(:stop)
        probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest)
        probe.enable
        test = ProbeTest.new
        test.expects(:instrumented_mymethod).with(1,2,3).raises
        lambda { test.mymethod(1,2,3) }.should raise_error
      end
    end

    describe "with a static label" do
      it "should send the label to the instrumentation layer" do
        probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest, :label => :mylabel)
        probe.enable
        test = ProbeTest.new
        Puppet::Util::Instrumentation.expects(:start).with { |label,data| label == :mylabel }.returns(42)
        Puppet::Util::Instrumentation.expects(:stop).with(:mylabel, 42, {})
        test.mymethod(1,2,3)
      end
    end

    describe "with a dynamic label" do
      it "should send the evaluated label to the instrumentation layer" do
        probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest, :label => Proc.new { |parent,args| "dynamic#{args[0]}" } )
        probe.enable
        test = ProbeTest.new
        Puppet::Util::Instrumentation.expects(:start).with { |label,data| label == "dynamic1" }.returns(42)
        Puppet::Util::Instrumentation.expects(:stop).with("dynamic1",42,{})
        test.mymethod(1,2,3)
      end
    end

    describe "with static data" do
      it "should send the data to the instrumentation layer" do
        probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest, :data => { :static_data => "nothing" })
        probe.enable
        test = ProbeTest.new
        Puppet::Util::Instrumentation.expects(:start).with { |label,data| data == { :static_data => "nothing" }}
        test.mymethod(1,2,3)
      end
    end

    describe "with dynamic data" do
      it "should send the evaluated label to the instrumentation layer" do
        probe = Puppet::Util::Instrumentation::Instrumentable::Probe.new(:mymethod, ProbeTest, :data => Proc.new { |parent, args| { :key => args[0] }  } )
        probe.enable
        test = ProbeTest.new
        Puppet::Util::Instrumentation.expects(:start).with { |label,data| data == { :key => 1 } }
        Puppet::Util::Instrumentation.expects(:stop)
        test.mymethod(1,2,3)
      end
    end
  end
end

describe Puppet::Util::Instrumentation::Instrumentable do
  before(:each) do
    class ProbeTest2
      extend Puppet::Util::Instrumentation::Instrumentable
      probe :mymethod
      def mymethod(arg1,arg2,arg3)
      end
    end
  end

  after do
    Puppet::Util::Instrumentation::Instrumentable.clear_probes
  end

  it "should allow probe definition" do
    Puppet::Util::Instrumentation::Instrumentable.probe_names.should be_include("ProbeTest2.mymethod")
  end

  it "should be able to enable all probes" do
    Puppet::Util::Instrumentation::Instrumentable.enable_probes
    ProbeTest2.new.should respond_to(:instrumented_mymethod)
  end
end
