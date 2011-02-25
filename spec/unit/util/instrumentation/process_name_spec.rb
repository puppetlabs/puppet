#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Util::Instrumentation::ProcessName do

  ProcessName = Puppet::Util::Instrumentation::ProcessName

  after(:each) do
    ProcessName.reason = {}
  end

  it "should be disabled by default" do
    ProcessName.should_not be_active
  end

  describe "when managing thread activity" do
    before(:each) do
      ProcessName.stubs(:setproctitle)
      ProcessName.stubs(:base).returns("base")
    end

    it "should be able to append activity" do
      thread1 = stub 'thread1'
      ProcessName.push_activity(:thread1,"activity1")
      ProcessName.push_activity(:thread1,"activity2")

      ProcessName.reason[:thread1].should == ["activity1", "activity2"]
    end

    it "should be able to remove activity" do
      ProcessName.push_activity(:thread1,"activity1")
      ProcessName.push_activity(:thread1,"activity1")
      ProcessName.pop_activity(:thread1)

      ProcessName.reason[:thread1].should == ["activity1"]
    end

    it "should maintain activity thread by thread" do
      ProcessName.push_activity(:thread1,"activity1")
      ProcessName.push_activity(:thread2,"activity2")

      ProcessName.reason[:thread1].should == ["activity1"]
      ProcessName.reason[:thread2].should == ["activity2"]
    end

    it "should set process title" do
      ProcessName.expects(:setproctitle)

      ProcessName.push_activity("thread1","activity1")
    end
  end

  describe "when computing the current process name" do
      before(:each) do
        ProcessName.stubs(:setproctitle)
        ProcessName.stubs(:base).returns("base")
      end

      it "should include every running thread activity" do
        thread1 = stub 'thread1', :inspect => "\#<Thread:0xdeadbeef run>", :hash => 1
        thread2 = stub 'thread2', :inspect => "\#<Thread:0x12344321 run>", :hash => 0

        ProcessName.push_activity(thread1,"Compiling node1.domain.com")
        ProcessName.push_activity(thread2,"Compiling node4.domain.com")
        ProcessName.push_activity(thread1,"Parsing file site.pp")
        ProcessName.push_activity(thread2,"Parsing file node.pp")

        ProcessName.process_name.should == "12344321 Compiling node4.domain.com,Parsing file node.pp | deadbeef Compiling node1.domain.com,Parsing file site.pp"
      end
  end

  describe "when finding base process name" do
      {:master => "master", :agent => "agent", :user => "puppet"}.each do |program,base|
        it "should return #{base} for #{program}" do
          Puppet.run_mode.stubs(:name).returns(program)
          ProcessName.base.should == base
        end
      end
  end

  describe "when finding a thread id" do
      it "should return the id from the thread inspect string" do
        thread = stub 'thread', :inspect => "\#<Thread:0x1234abdc run>"
        ProcessName.thread_id(thread).should == "1234abdc"
      end
  end

  describe "when scrolling the instrumentation string" do
      it "should rotate the string of various step" do
        ProcessName.rotate("this is a rotation", 10).should == "rotation -- this is a "
      end

      it "should not rotate the string for the 0 offset" do
        ProcessName.rotate("this is a rotation", 0).should == "this is a rotation"
      end
  end

  describe "when setting process name" do
    before(:each) do
      ProcessName.stubs(:process_name).returns("12345 activity")
      ProcessName.stubs(:base).returns("base")
      @oldname = $0
    end

    after(:each) do
      $0 = @oldname
    end

    it "should not do it if the feature is disabled" do
      ProcessName.setproctitle

      $0.should_not == "base: 12345 activity"
    end

    it "should do it if the feature is enabled" do
      ProcessName.active = true
      ProcessName.setproctitle

      $0.should == "base: 12345 activity"
    end
  end

  describe "when setting a probe" do
    before(:each) do
      thread = stub 'thread', :inspect => "\#<Thread:0x1234abdc run>"
      Thread.stubs(:current).returns(thread)
      Thread.stubs(:new)
      ProcessName.active = true
    end

    it "should start the scroller thread" do
      Thread.expects(:new)
      ProcessName.instrument("doing something") do
      end
    end

    it "should push current thread activity and execute the block" do
      ProcessName.instrument("doing something") do
        $0.should == "puppet: 1234abdc doing something"
      end
    end

    it "should finally pop the activity" do
      ProcessName.instrument("doing something") do
      end
      $0.should == "puppet: "
    end
  end

  describe "when enabling" do
    before do
      Thread.stubs(:new)
      ProcessName.stubs(:setproctitle)
    end

    it "should be active" do
      ProcessName.enable
      ProcessName.should be_active
    end

    it "should set the new process name" do
      ProcessName.expects(:setproctitle)
      ProcessName.enable
    end
  end

  describe "when disabling" do
    it "should set active to false" do
      ProcessName.active = true
      ProcessName.disable
      ProcessName.should_not be_active
    end

    it "should restore the old process name" do
      oldname = $0
      ProcessName.active = true
      ProcessName.setproctitle
      ProcessName.disable
      $0.should == oldname
    end
  end

  describe "when scrolling" do
    it "should do nothing for shorter process names" do
      ProcessName.expects(:setproctitle).never
      ProcessName.scroll
    end

    it "should call setproctitle" do
      ProcessName.stubs(:process_name).returns("x" * 60)
      ProcessName.expects(:setproctitle)
      ProcessName.scroll
    end

    it "should increment rotation offset" do
      name = "x" * 60
      ProcessName.active = true
      ProcessName.stubs(:process_name).returns(name)
      ProcessName.expects(:rotate).once.with(name,1).returns("")
      ProcessName.expects(:rotate).once.with(name,2).returns("")
      ProcessName.scroll
      ProcessName.scroll
    end
  end

end