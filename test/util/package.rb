#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppet/util/package'
require 'puppettest'

class TestPuppetUtilPackage < Test::Unit::TestCase
  include PuppetTest
  include Puppet::Util::Package

  def test_versioncmp
    ary = %w{ 1.1.6 2.3 1.1a 3.0 1.5 1 2.4 1.1-4 2.3.1 1.2 2.3.0 1.1-3 2.4b 2.4 2.40.2 2.3a.1 3.1 0002 1.1-5 1.1.a 1.06}

    newary = nil
    assert_nothing_raised do
      newary = ary.sort { |a, b|
        versioncmp(a,b)
      }
    end
    assert_equal(["0002", "1", "1.06", "1.1-3", "1.1-4", "1.1-5", "1.1.6", "1.1.a", "1.1a", "1.2", "1.5", "2.3", "2.3.0", "2.3.1", "2.3a.1", "2.4", "2.4", "2.4b", "2.40.2", "3.0", "3.1"], newary)
  end
end

