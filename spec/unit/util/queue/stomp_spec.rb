#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/queue'

describe Puppet::Util::Queue, :if => Puppet.features.stomp? do
  it 'should load :stomp client appropriately' do
    Puppet::Util::Queue.queue_type_to_class(:stomp).name.should == 'Puppet::Util::Queue::Stomp'
  end
end

describe 'Puppet::Util::Queue::Stomp', :if => Puppet.features.stomp? do
  before do
    # So we make sure we never create a real client instance.
    # Otherwise we'll try to connect, and that's bad.
    Stomp::Client.stubs(:new).returns stub("client", :publish => true)
  end

  it 'should be registered with Puppet::Util::Queue as :stomp type' do
    Puppet::Util::Queue.queue_type_to_class(:stomp).should == Puppet::Util::Queue::Stomp
  end

  describe "when initializing" do
    it "should create a Stomp client instance" do
      Stomp::Client.expects(:new).returns stub("stomp_client", :publish => true)
      Puppet::Util::Queue::Stomp.new
    end

    it "should provide helpful failures when the queue source is not a valid source" do
      Puppet[:queue_source] = "-----"

      expect { Puppet::Util::Queue::Stomp.new }.to raise_error(ArgumentError, /not a Stomp URL/)
    end

    it "should fail unless the queue source is a stomp URL" do
      Puppet[:queue_source] = "http://foo/bar"

      expect { Puppet::Util::Queue::Stomp.new }.to raise_error(ArgumentError, /not a Stomp URL/)
    end

    it "should fail somewhat helpfully if the Stomp client cannot be created" do
      Stomp::Client.expects(:new).raises RuntimeError
      expect { Puppet::Util::Queue::Stomp.new }.to raise_error(ArgumentError)
    end

    list = %w{user password host port}
    {"user" => "myuser", "password" => "mypass", "host" => "foohost", "port" => 42}.each do |name, value|
      it "should use the #{name} from the queue source as the queueing #{name}" do
        Puppet[:queue_source] = "stomp://myuser:mypass@foohost:42/"

        Stomp::Client.expects(:new).with { |*args| args[list.index(name)] == value }
        Puppet::Util::Queue::Stomp.new
      end
    end

    it "should create a reliable client instance" do
      Puppet[:queue_source] = "stomp://myuser@foohost:42/"

      Stomp::Client.expects(:new).with { |*args| args[4] == true }
      Puppet::Util::Queue::Stomp.new
    end
  end

  describe "when publishing a message" do
    before do
      @client = stub 'client', :publish => true
      Stomp::Client.stubs(:new).returns @client
      @queue = Puppet::Util::Queue::Stomp.new
    end

    it "should publish it to the queue client instance" do
      @client.expects(:publish).with { |queue, msg, options| msg == "Smite!" }
      @queue.publish_message('fooqueue', 'Smite!')
    end

    it "should publish it to the transformed queue name" do
      @client.expects(:publish).with { |queue, msg, options| queue == "/queue/fooqueue" }
      @queue.publish_message('fooqueue', 'Smite!')
    end

    it "should publish it as a persistent message" do
      @client.expects(:publish).with { |queue, msg, options| options[:persistent] == true }
      @queue.publish_message('fooqueue', 'Smite!')
    end

    it "should use send when the gem does not support publish" do
      Stomp::Client.stubs(:new).returns(stub('client', :send => true))
      Puppet::Util::Queue::Stomp.new.publish_message('fooqueue', 'Smite!')
    end
  end

  describe "when subscribing to a queue" do
    before do
      @client = stub 'client', :acknowledge => true, :publish => true
      Stomp::Client.stubs(:new).returns @client
      @queue = Puppet::Util::Queue::Stomp.new
    end

    it "should subscribe via the queue client instance" do
      @client.expects(:subscribe)
      @queue.subscribe('fooqueue')
    end

    it "should subscribe to the transformed queue name" do
      @client.expects(:subscribe).with { |queue, options| queue == "/queue/fooqueue" }
      @queue.subscribe('fooqueue')
    end

    it "should specify that its messages should be acknowledged" do
      @client.expects(:subscribe).with { |queue, options| options[:ack] == :client }
      @queue.subscribe('fooqueue')
    end

    it "should yield the body of any received message" do
      message = mock 'message'
      message.expects(:body).returns "mybody"

      @client.expects(:subscribe).yields(message)

      body = nil
      @queue.subscribe('fooqueue') { |b| body = b }
      body.should == "mybody"
    end

    it "should acknowledge all successfully processed messages" do
      message = stub 'message', :body => "mybode"

      @client.stubs(:subscribe).yields(message)
      @client.expects(:acknowledge).with(message)

      @queue.subscribe('fooqueue') { |b| "eh" }
    end
  end

  it 'should transform the simple queue name to "/queue/<queue_name>"' do
    Puppet::Util::Queue::Stomp.new.stompify_target('blah').should == '/queue/blah'
  end
end
