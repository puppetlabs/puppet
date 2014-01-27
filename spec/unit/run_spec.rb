#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/agent'
require 'puppet/run'

describe Puppet::Run do
  before do
    @runner = Puppet::Run.new
  end

  it "should indirect :run" do
    Puppet::Run.indirection.name.should == :run
  end

  it "should use a configurer agent as its agent" do
    agent = mock 'agent'
    Puppet::Agent.expects(:new).with(Puppet::Configurer, anything).returns agent

    @runner.agent.should equal(agent)
  end

  it "should accept options at initialization" do
    expect do
      Puppet::Run.new(
        :background => true,
        :tags => 'tag',
        :ignoreschedules => false,
        :pluginsync => true)
    end.not_to raise_error
  end

  it "should not accept arbitrary options" do
    lambda { Puppet::Run.new(:foo => true) }.should raise_error(ArgumentError)
  end

  it "should default to running in the foreground" do
    Puppet::Run.new.should_not be_background
  end

  it "should default to its options being an empty hash" do
    Puppet::Run.new.options.should == {}
  end

  it "should accept :tags for the agent" do
    Puppet::Run.new(:tags => "foo").options[:tags].should == "foo"
  end

  it "should accept :ignoreschedules for the agent" do
    Puppet::Run.new(:ignoreschedules => true).options[:ignoreschedules].should be_true
  end

  it "should accept an option to configure it to run in the background" do
    Puppet::Run.new(:background => true).should be_background
  end

  it "should retain the background option" do
    Puppet::Run.new(:background => true).options[:background].should be_nil
  end

  describe "when asked to run" do
    before do
      @agent = stub 'agent', :run => nil, :running? => false
      @runner.stubs(:agent).returns @agent
    end

    it "should run its agent" do
      agent = stub 'agent2', :running? => false
      @runner.stubs(:agent).returns agent

      agent.expects(:run)

      @runner.run
    end

    it "should pass any of its options on to the agent" do
      @runner.stubs(:options).returns(:foo => :bar)
      @agent.expects(:run).with(:foo => :bar)

      @runner.run
    end

    it "should log its run using the provided options" do
      @runner.expects(:log_run)

      @runner.run
    end

    it "should set its status to 'already_running' if the agent is already running" do
      @agent.expects(:running?).returns true

      @runner.run

      @runner.status.should == "running"
    end

    it "should set its status to 'success' if the agent is run" do
      @agent.expects(:running?).returns false

      @runner.run

      @runner.status.should == "success"
    end

    it "should run the agent in a thread if asked to run it in the background" do
      Thread.expects(:new)

      @runner.expects(:background?).returns true

      @agent.expects(:run).never # because our thread didn't yield

      @runner.run
    end

    it "should run the agent directly if asked to run it in the foreground" do
      Thread.expects(:new).never

      @runner.expects(:background?).returns false
      @agent.expects(:run)

      @runner.run
    end
  end

  describe ".from_data_hash" do
    it "should read from a hash that represents the 'options' to initialize" do
      options = {
        "tags" => "whatever",
        "background" => true,
        "ignoreschedules" => false,
      }
      run = Puppet::Run.from_data_hash(options)

      run.options.should == {
        :tags => "whatever",
        :pluginsync => Puppet[:pluginsync],
        :ignoreschedules => false,
      }
      run.background.should be_true
    end

    it "should read from a hash that follows the actual object structure" do
      hash = {"background" => true,
              "options" => {
                "pluginsync" => true,
                "tags" => [],
                "ignoreschedules" => false},
              "status" => "success"}
      run = Puppet::Run.from_data_hash(hash)

      run.options.should == {
        :pluginsync => true,
        :tags => [],
        :ignoreschedules => false
      }
      run.background.should be_true
      run.status.should == 'success'
    end

    it "should round trip through pson" do
      run = Puppet::Run.new(
        :tags => ['a', 'b', 'c'],
        :ignoreschedules => true,
        :pluginsync => false,
        :background => true
      )
      run.instance_variable_set(:@status, true)

      tripped = Puppet::Run.convert_from(:pson, run.render(:pson))

      tripped.options.should == run.options
      tripped.status.should == run.status
      tripped.background.should == run.background
    end
  end
end
