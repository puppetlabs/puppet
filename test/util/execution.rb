#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppettest'

class TestPuppetUtilExecution < Test::Unit::TestCase
  include PuppetTest

  def test_withenv
    ENV["testing"] = "yay"

    assert_nothing_raised do
      Puppet::Util::Execution.withenv :testing => "foo" do
        $ran = ENV["testing"]
      end
    end

    assert_equal("yay", ENV["testing"])
    assert_equal("foo", $ran)

    ENV["rah"] = "yay"
    assert_raise(ArgumentError) do
      Puppet::Util::Execution.withenv :testing => "foo" do
        raise ArgumentError, "yay"
      end
    end

    assert_equal("yay", ENV["rah"])
  end
end

