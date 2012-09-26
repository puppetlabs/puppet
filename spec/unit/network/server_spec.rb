#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/server'

describe Puppet::Network::Server do
  let(:port) { 8140 }
  let(:address) { '0.0.0.0' }
  let(:server) {
    server = Puppet::Network::Server.new(address, port)
    server.stubs(:close_streams)
    server
  }

  before do
    @mock_http_server = mock('http server')
    Puppet.settings.stubs(:use)
    Puppet.run_mode.stubs(:name).returns :master
    Puppet::Network::HTTP::WEBrick.stubs(:new).returns(@mock_http_server)
  end

  describe "when initializing" do
    before do
      Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')
      Puppet[:masterport] = ''
    end

    it "should allow registering REST handlers" do
      server = Puppet::Network::Server.new(address, port, [:foo, :bar, :baz])
      expect { server.unregister(:foo, :bar, :baz) }.to_not raise_error
    end

    it "should not be listening after initialization" do
      Puppet::Network::Server.new(address, port).should_not be_listening
    end

    it "should use the :main setting section" do
      Puppet.settings.expects(:use).with { |*args| args.include?(:main) }
      Puppet::Network::Server.new(address, port)
    end

    it "should use the :application setting section" do
      Puppet.settings.expects(:use).with { |*args| args.include?(:application) }

      Puppet::Network::Server.new(address, port)
    end
  end

  describe "when being started" do
    before do
      server.stubs(:listen)
      server.stubs(:create_pidfile)
    end

    it "should listen" do
      server.expects(:listen)
      server.start
    end

    it "should create its PID file" do
      server.expects(:create_pidfile)
      server.start
    end
  end

  describe "when being stopped" do
    before do
      server.stubs(:unlisten)
      server.stubs(:remove_pidfile)
    end

    it "should unlisten" do
      server.expects(:unlisten)
      server.stop
    end

    it "should remove its PID file" do
      server.expects(:remove_pidfile)
      server.stop
    end
  end

  describe "when creating its pidfile" do
    it "should use an exclusive mutex" do
      Puppet.run_mode.expects(:name).returns "me"
      Puppet::Util.expects(:synchronize_on).with("me", Sync::EX)
      server.create_pidfile
    end

    it "should lock the pidfile using the Pidlock class" do
      pidfile = mock 'pidfile'

      Puppet.run_mode.expects(:name).returns "eh"
      Puppet[:pidfile] = File.expand_path("/my/file")

      Puppet::Util::Pidlock.expects(:new).with(Puppet[:pidfile]).returns pidfile

      pidfile.expects(:lock).returns true
      server.create_pidfile
    end

    it "should fail if it cannot lock" do
      pidfile = mock 'pidfile'

      Puppet[:pidfile] = File.expand_path("/my/file")

      Puppet::Util::Pidlock.expects(:new).with(Puppet[:pidfile]).returns pidfile

      pidfile.expects(:lock).returns false

      expect { server.create_pidfile }.to raise_error /Could not create PID/
    end
  end

  describe "when removing its pidfile" do
    it "should use an exclusive mutex" do
      Puppet.run_mode.expects(:name).returns "me"
      Puppet::Util.expects(:synchronize_on).with("me",Sync::EX)
      server.remove_pidfile
    end

    it "should do nothing if the pidfile is not present" do
      pidfile = mock 'pidfile', :unlock => false
      Puppet[:pidfile] = "/my/file"
      Puppet::Util::Pidlock.expects(:new).with(Puppet[:pidfile]).returns pidfile

      server.remove_pidfile
    end

    it "should unlock the pidfile using the Pidlock class" do
      pidfile = mock 'pidfile', :unlock => true
      Puppet[:pidfile] = "/my/file"
      Puppet::Util::Pidlock.expects(:new).with(Puppet[:pidfile]).returns pidfile

      server.remove_pidfile
    end
  end

  describe "when managing indirection registrations" do
    before do
      Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')
    end

    it "should allow registering an indirection for client access by specifying its indirection name" do
      expect { server.register(:foo) }.to_not raise_error
    end

    it "should require that the indirection be valid" do
      Puppet::Indirector::Indirection.expects(:model).with(:foo).returns nil
      expect { server.register(:foo) }.to raise_error(ArgumentError)
    end

    it "should require at least one indirection name when registering indirections for client access" do
      expect { server.register }.to raise_error(ArgumentError)
    end

    it "should allow for numerous indirections to be registered at once for client access" do
      expect { server.register(:foo, :bar, :baz) }.to_not raise_error
    end

    it "should allow the use of indirection names to specify which indirections are to be no longer accessible to clients" do
      server.register(:foo)
      expect { server.unregister(:foo) }.to_not raise_error
    end

    it "should leave other indirections accessible to clients when turning off indirections" do
      server.register(:foo, :bar)
      server.unregister(:foo)
      expect { server.unregister(:bar)}.to_not raise_error
    end

    it "should allow specifying numerous indirections which are to be no longer accessible to clients" do
      server.register(:foo, :bar)
      expect { server.unregister(:foo, :bar) }.to_not raise_error
    end

    it "should not turn off any indirections if given unknown indirection names to turn off" do
      server.register(:foo, :bar)
      expect { server.unregister(:foo, :bar, :baz) }.to raise_error(ArgumentError)
      expect { server.unregister(:foo, :bar) }.to_not raise_error
    end

    it "should not allow turning off unknown indirection names" do
      server.register(:foo, :bar)
      expect { server.unregister(:baz) }.to raise_error(ArgumentError)
    end

    it "should disable client access immediately when turning off indirections" do
      server.register(:foo, :bar)
      server.unregister(:foo)
      expect { server.unregister(:foo) }.to raise_error(ArgumentError)
    end

    it "should allow turning off all indirections at once" do
      server.register(:foo, :bar)
      server.unregister
      [:foo, :bar, :baz].each do |indirection|
        expect { server.unregister(indirection) }.to raise_error(ArgumentError)
      end
    end
  end

  it "should allow for multiple configurations, each handling different indirections" do
    Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')

    server2 = Puppet::Network::Server.new(address, port)
    server.register(:foo, :bar)
    server2.register(:foo, :xyzzy)
    server.unregister(:foo, :bar)
    server2.unregister(:foo, :xyzzy)
    expect { server.unregister(:xyzzy) }.to raise_error(ArgumentError)
    expect { server2.unregister(:bar) }.to raise_error(ArgumentError)
  end

  describe "when listening is off" do
    before do
      @mock_http_server.stubs(:listen)
    end

    it "should indicate that it is not listening" do
      server.should_not be_listening
    end

    it "should not allow listening to be turned off" do
      expect { server.unlisten }.to raise_error(RuntimeError)
    end

    it "should allow listening to be turned on" do
      expect { server.listen }.to_not raise_error
    end

  end

  describe "when listening is on" do
    before do
      @mock_http_server.stubs(:listen)
      @mock_http_server.stubs(:unlisten)
      server.listen
    end

    it "should indicate that it is listening" do
      server.should be_listening
    end

    it "should not allow listening to be turned on" do
      expect { server.listen }.to raise_error(RuntimeError)
    end

    it "should allow listening to be turned off" do
      expect { server.unlisten }.to_not raise_error
    end
  end

  describe "when listening is being turned on" do
    before do
      Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')
    end

    it "should cause the HTTP server to listen" do
      server = Puppet::Network::Server.new(address, port, [:node])
      @mock_http_server.expects(:listen).with(address, port)
      server.listen
    end
  end

  describe "when listening is being turned off" do
    before do
      @mock_http_server.stubs(:listen)
      server.stubs(:http_server).returns(@mock_http_server)
      server.listen
    end

    it "should cause the HTTP server to stop listening" do
      @mock_http_server.expects(:unlisten)
      server.unlisten
    end

    it "should not allow for indirections to be turned off" do
      Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')

      server.register(:foo)
      expect { server.unregister(:foo) }.to raise_error(RuntimeError)
    end
  end
end
