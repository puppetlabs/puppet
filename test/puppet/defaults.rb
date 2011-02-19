#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppettest'


class TestPuppetDefaults < Test::Unit::TestCase
  include PuppetTest
  @@dirs = %w{rrddir confdir vardir logdir statedir}
  @@files = %w{statefile manifest masterlog}
  @@normals = %w{puppetport masterport server}
  @@booleans = %w{noop}

  def testVersion
    assert( Puppet.version =~ /^[0-9]+(\.[0-9]+)*/, "got invalid version number #{Puppet.version}")
  end

  def testStringOrParam
    [@@dirs,@@files,@@booleans].flatten.each { |param|
      assert_nothing_raised { Puppet[param] }
      assert_nothing_raised { Puppet[param.intern] }
    }
  end

  def test_valuesForEach
    [@@dirs,@@files,@@booleans].flatten.each { |param|
      param = param.intern
      assert_nothing_raised { Puppet[param] }
    }
  end

  def testValuesForEach
    [@@dirs,@@files,@@booleans].flatten.each { |param|
      assert_nothing_raised { Puppet[param] }
    }
  end

  # we don't want user defaults in /, or root defaults in ~
  def testDefaultsInCorrectRoots
    notval = nil
    if Puppet.features.root?
      notval = Regexp.new(File.expand_path("~"))
    else
      notval = /^\/var|^\/etc/
    end
    [@@dirs,@@files].flatten.each { |param|
      value = Puppet[param]

      assert_nothing_raised { raise "#{param} is incorrectly set to #{value}" } unless value !~ notval
    }
  end

  def test_settingdefaults
    testvals = {
      :fakeparam => "$confdir/yaytest",
      :anotherparam => "$vardir/goodtest",
      :string => "a yay string",
      :boolean => true
    }

    testvals.each { |param, default|
      assert_nothing_raised {
        Puppet.setdefaults("testing", param => [default, "a value"])
      }
    }
  end
end
