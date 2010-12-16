#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/network/xmlrpc/processor'
require 'mocha'

class TestXMLRPCProcessor < Test::Unit::TestCase
  include PuppetTest
  class BaseProcessor
    def add_handler(interface, handler)
      @handlers ||= {}
      @handlers[interface] = handler
    end
  end

  # We use a base class just so super() works with add_handler.
  class Processor < BaseProcessor
    include Puppet::Network::XMLRPCProcessor

    def set_service_hook(&block)
      meta_def(:service, &block)
    end
  end

  def setup
    super
    Puppet::Util::SUIDManager.stubs(:asuser).yields
    @processor = Processor.new
  end

  def test_handlers
    ca = Puppet::Network::Handler.ca
    @processor.send(:setup_processor)
    assert(! @processor.handler_loaded?(:ca), "already have ca handler loaded")
    assert_nothing_raised do
      @processor.add_handler(ca.interface, ca.new)
    end

    assert(@processor.handler_loaded?(:puppetca), "ca handler not loaded by symbol")
    assert(@processor.handler_loaded?("puppetca"), "ca handler not loaded by string")
  end

  def test_process
    ca = Puppet::Network::Handler.ca
    @processor.send(:setup_processor)
    assert_nothing_raised do
      @processor.add_handler(ca.interface, ca.new)
    end

    fakeparser = Class.new do
      def parseMethodCall(data)
        data
      end
    end

    request = Puppet::Network::ClientRequest.new("fake", "192.168.0.1", false)
    request.handler = "myhandler"
    request.method = "mymethod"

    @processor.expects(:parser).returns(fakeparser.new)

    request.expects(:handler=).with("myhandler")
    request.expects(:method=).with("mymethod")

    @processor.stubs(:verify)
    @processor.expects(:handle).with(request.call, "params", request.name, request.ip)

    @processor.send(:process, ["myhandler.mymethod", ["params"]], request)
  end

  def test_setup_processor
    @processor.expects(:set_service_hook)
    @processor.send(:setup_processor)
  end
end


