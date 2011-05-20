#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/network/handler/runner'

class TestHandlerRunner < Test::Unit::TestCase
  include PuppetTest

  def test_it_calls_agent_runner
    runner = mock 'runner'
    Puppet::Run.expects(:new).with(:tags => "mytags", :ignoreschedules => true, :background => false).returns runner
    runner.expects(:run)
    runner.expects(:status).returns "yay"


    assert_equal("yay", Puppet::Network::Handler.runner.new.run("mytags", true, true))
  end
end
