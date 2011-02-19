#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppettest'

class TestError < Test::Unit::TestCase
  include PuppetTest

  def test_errorisstring
    error = nil
    assert_nothing_raised {
      error = Puppet::ParseError.new("This is an error")
    }
    assert_instance_of(String, error.to_s)
  end
end

