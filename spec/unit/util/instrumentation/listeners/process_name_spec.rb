#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/util/instrumentation'

Puppet::Util::Instrumentation.init
process_name = Puppet::Util::Instrumentation.listener(:process_name)

describe process_name do
  before(:each) do
    @process_name = process_name.new
  end

  it "should have a notify method" do
    @process_name.should respond_to(:notify)
  end

  it "should not have a data method" do
    @process_name.should_not respond_to(:data)
  end

  describe "when managing thread activity" do
    before(:each) do
      @process_name.stubs(:setproctitle)
      @process_name.stubs(:base).returns("base")
    end

    it "should be able to append activity" do
      thread1 = stub 'thread1'
      @process_name.push_activity(:thread1,"activity1")
      @process_name.push_activity(:thread1,"activity2")

      @process_name.reason[:thread1].should == ["activity1", "activity2"]
    end

    it "should be able to remove activity" do
      @process_name.push_activity(:thread1,"activity1")
      @process_name.push_activity(:thread1,"activity1")
      @process_name.pop_activity(:thread1)

      @process_name.reason[:thread1].should == ["activity1"]
    end

    it "should maintain activity thread by thread" do
      @process_name.push_activity(:thread1,"activity1")
      @process_name.push_activity(:thread2,"activity2")

      @process_name.reason[:thread1].should == ["activity1"]
      @process_name.reason[:thread2].should == ["activity2"]
    end

    it "should set process title" do
      @process_name.expects(:setproctitle)

      @process_name.push_activity("thread1","activity1")
    end
  end

  describe "when computing the current process name" do
    before(:each) do
      @process_name.stubs(:setproctitle)
      @process_name.stubs(:base).returns("base")
    end

    it "should include every running thread activity" do
      thread1 = stub 'thread1', :inspect => "\#<Thread:0xdeadbeef run>", :hash => 1
      thread2 = stub 'thread2', :inspect => "\#<Thread:0x12344321 run>", :hash => 0

      @process_name.push_activity(thread1,"Compiling node1.domain.com")
      @process_name.push_activity(thread2,"Compiling node4.domain.com")
      @process_name.push_activity(thread1,"Parsing file site.pp")
      @process_name.push_activity(thread2,"Parsing file node.pp")

      @process_name.process_name.should =~ /12344321 Compiling node4.domain.com,Parsing file node.pp/
      @process_name.process_name.should =~ /deadbeef Compiling node1.domain.com,Parsing file site.pp/
    end
  end

  describe "when finding base process name" do
    {:master => "master", :agent => "agent", :user => "puppet"}.each do |program,base|
      it "should return #{base} for #{program}" do
        Puppet.run_mode.stubs(:name).returns(program)
        @process_name.base.should == base
      end
    end
  end

  describe "when finding a thread id" do
    it "should return the id from the thread inspect string" do
      thread = stub 'thread', :inspect => "\#<Thread:0x1234abdc run>"
      @process_name.thread_id(thread).should == "1234abdc"
    end
  end

  describe "when scrolling the instrumentation string" do
    it "should rotate the string of various step" do
      @process_name.rotate("this is a rotation", 10).should == "rotation -- this is a "
    end

    it "should not rotate the string for the 0 offset" do
      @process_name.rotate("this is a rotation", 0).should == "this is a rotation"
    end
  end

  describe "when setting process name" do
    before(:each) do
      @process_name.stubs(:process_name).returns("12345 activity")
      @process_name.stubs(:base).returns("base")
      @oldname = $0
    end

    after(:each) do
      $0 = @oldname
    end

    it "should do it if the feature is enabled" do
      @process_name.setproctitle

      $0.should == "base: 12345 activity"
    end
  end

  describe "when subscribed" do
    before(:each) do
      thread = stub 'thread', :inspect => "\#<Thread:0x1234abdc run>"
      Thread.stubs(:current).returns(thread)
    end

    it "should start the scroller" do
      Thread.expects(:new)
      @process_name.subscribed
    end
  end

  describe "when unsubscribed" do
    before(:each) do
      @thread = stub 'scroller', :inspect => "\#<Thread:0x1234abdc run>"
      Thread.stubs(:new).returns(@thread)
      Thread.stubs(:kill)
      @oldname = $0
      @process_name.subscribed
    end

    after(:each) do
      $0 = @oldname
    end

    it "should stop the scroller" do
      Thread.expects(:kill).with(@thread)
      @process_name.unsubscribed
    end

    it "should reset the process name" do
      $0 = "let's see what happens"
      @process_name.unsubscribed
      $0.should == @oldname
    end
  end

  describe "when setting a probe" do
    before(:each) do
      thread = stub 'thread', :inspect => "\#<Thread:0x1234abdc run>"
      Thread.stubs(:current).returns(thread)
      Thread.stubs(:new)
      @process_name.active = true
    end

    it "should push current thread activity and execute the block" do
      @process_name.notify(:instrumentation, :start, {})
      $0.should == "puppet: 1234abdc instrumentation"
      @process_name.notify(:instrumentation, :stop, {})
    end

    it "should finally pop the activity" do
      @process_name.notify(:instrumentation, :start, {})
      @process_name.notify(:instrumentation, :stop, {})
      $0.should == "puppet: "
    end
  end

  describe "when scrolling" do
    it "should do nothing for shorter process names" do
      @process_name.expects(:setproctitle).never
      @process_name.scroll
    end

    it "should call setproctitle" do
      @process_name.stubs(:process_name).returns("x" * 60)
      @process_name.expects(:setproctitle)
      @process_name.scroll
    end

    it "should increment rotation offset" do
      name = "x" * 60
      @process_name.stubs(:process_name).returns(name)
      @process_name.expects(:rotate).once.with(name,1).returns("")
      @process_name.expects(:rotate).once.with(name,2).returns("")
      @process_name.scroll
      @process_name.scroll
    end
  end
end