#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppet/provider'
require 'puppettest'

class TestImpl < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    @type = newtype(@method_name.to_s + "type")

    # But create a new provider for every method.
    @provider = newprovider(@method_name.to_s + "provider")
  end

  def newtype(name)
    # First create a fake type
    return Puppet::Type.newtype(name) {
      newparam(:name) { isnamevar }
    }
  end

  def newprovider(name, type = nil)
    type ||= @type
    provider = nil
    assert_nothing_raised("Could not create provider") do
      provider = type.provide(name) {}
    end
    provider
  end

  def test_provider_default
    nondef = nil
    assert_nothing_raised {
      nondef = newprovider(:nondefault)
    }

    assert_nothing_raised do
      @provider.defaultfor :operatingsystem => Facter["operatingsystem"].value
    end

    assert_equal(@provider.name, @type.defaultprovider.name, "Did not get right provider")

    @type.suitableprovider
  end

  def test_subclassconfines
    parent = newprovider("parentprovider")

    # Now make a bad confine on the parent
    parent.confine :exists => "/this/file/definitely/does/not/exist"

    child = nil
    assert_nothing_raised {
      child = @type.provide("child", :parent => parent.name) {}
    }

    assert(child.suitable?, "Parent ruled out child")
  end

  def test_commands
    parent = newprovider("parentprovider")

    child = nil
    assert_nothing_raised {
      child = @type.provide("child", :parent => parent.name) {}
    }

    assert_raise(Puppet::DevError) do
      child.command(:nosuchcommand)
    end

    # Now create a parent command
    assert_nothing_raised {
      parent.commands :sh => Puppet::Util.which('sh')
    }

    assert(parent.command(:sh), "Did not find 'sh' command")

    assert(child.command(:sh), "Did not find parent's 'sh' command")

    assert(FileTest.exists?(child.command(:sh)),
                "Somehow broke path to sh")
  end
end

