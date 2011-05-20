#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-01-28.
#  Copyright (c) 2007. All rights reserved.

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/puppettest')

require 'puppettest'

class TestBaseServiceProvider < Test::Unit::TestCase
  include PuppetTest

  def test_base
    running = tempfile

    commands = {}
    %w{touch rm test}.each do |c|
      path = %x{which #{c}}.chomp
      if path == ""
        $stderr.puts "Cannot find '#{c}'; cannot test base service provider"
        return
      end
      commands[c.to_sym] = path
    end

          service = Puppet::Type.type(:service).new(
                
      :name => "yaytest", :provider => :base,
      :start => "#{commands[:touch]} #{running}",
      :status => "#{commands[:test]} -f #{running}",
        
      :stop => "#{commands[:rm]} #{running}"
    )

    provider = service.provider
    assert(provider, "did not get base provider")

    assert_nothing_raised do
      provider.start
    end
    assert(FileTest.exists?(running), "start was not called correctly")
    assert_nothing_raised do
      assert_equal(:running, provider.status, "status was not returned correctly")
    end
    assert_nothing_raised do
      provider.stop
    end
    assert(! FileTest.exists?(running), "stop was not called correctly")
    assert_nothing_raised do
      assert_equal(:stopped, provider.status, "status was not returned correctly")
    end
  end

  # Testing #454
  def test_that_failures_propagate
    nope = "/no/such/command"

          service = Puppet::Type.type(:service).new(
                
      :name => "yaytest", :provider => :base,
      :start => nope,
      :status => nope,
      :stop => nope,
        
      :restart => nope
    )

    provider = service.provider
    assert(provider, "did not get base provider")

    # We can't fail well when status is messed up, because we depend on the return code
    # of the command for data.
    %w{start stop restart}.each do |command|
      assert_raise(Puppet::Error, "did not throw error when #{command} failed") do
        provider.send(command)
      end
    end
  end
end

