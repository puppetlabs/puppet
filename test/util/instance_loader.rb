#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppet/util/instance_loader'
require 'puppettest'

class TestInstanceloader < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    @loader = Class.new do
      extend Puppet::Util::InstanceLoader

      def self.newstuff(name, value)
        instance_hash(:stuff)[name] = value
      end
    end

    assert_nothing_raised("Could not create instance loader") do
      @loader.instance_load(:stuff, "puppet/stuff")
    end
  end

  # Make sure we correctly create our autoload instance.  This covers the basics.
  def test_autoload
    # Make sure we can retrieve the loader
    assert_instance_of(Puppet::Util::Autoload, @loader.instance_loader(:stuff), "Could not get instance loader")

    # Make sure we can get the instance hash
    assert(@loader.instance_hash(:stuff), "Could not get instance hash")

    # Make sure it defines the instance retrieval method
    assert(@loader.respond_to?(:stuff), "Did not define instance retrieval method")
  end

  def test_loaded_instances
    assert_equal([], @loader.loaded_instances(:stuff), "Incorrect loaded instances")

    @loader.newstuff(:testing, "a value")

    assert_equal([:testing], @loader.loaded_instances(:stuff), "Incorrect loaded instances")

    assert_equal("a value", @loader.loaded_instance(:stuff, :testing), "Got incorrect loaded instance")
  end

  def test_instance_loading
  end
end

