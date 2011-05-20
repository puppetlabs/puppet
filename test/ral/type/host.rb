#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'test/unit'
require 'facter'

class TestHost < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    @hosttype = Puppet::Type.type(:host)

    @provider = @hosttype.defaultprovider

    # Make sure they are using the parsed provider
    unless @provider.name == :parsed
      @hosttype.defaultprovider = @hosttype.provider(:parsed)
    end

    cleanup do @hosttype.defaultprovider = nil end

    if @provider.respond_to?(:default_target=)
      @default_file = @provider.default_target
      cleanup do
        @provider.default_target = @default_file
      end
      @target = tempfile
      @provider.default_target = @target
    end
  end

  def mkhost
    if defined?(@hcount)
      @hcount += 1
    else
      @hcount = 1
    end

    @catalog ||= mk_catalog

    host = nil
    assert_nothing_raised {

            host = Puppet::Type.type(:host).new(
                
        :name => "fakehost#{@hcount}",
        :ip => "192.168.27.#{@hcount}",
        :alias => "alias#{@hcount}",
        
        :catalog => @catalog
      )
    }

    host
  end

  def test_list
    list = nil
    assert_nothing_raised do
      list = @hosttype.defaultprovider.instances
    end

    assert_equal(0, list.length, "Found hosts in empty file somehow")
  end


  def test_simplehost
    host = nil

    assert_nothing_raised {

            host = Puppet::Type.type(:host).new(
                
        :name => "culain",
        
        :ip => "192.168.0.3"
      )
    }

    current_values = nil
    assert_nothing_raised { current_values = host.retrieve }
    assert_events([:host_created], host)

    assert_nothing_raised { current_values = host.retrieve }

    assert_equal(:present, current_values[host.property(:ensure)])

    host[:ensure] = :absent

    assert_events([:host_removed], host)

    assert_nothing_raised { current_values = host.retrieve }

    assert_equal(:absent, current_values[host.property(:ensure)])
  end

  def test_moddinghost
    host = mkhost
    cleanup do
      host[:ensure] = :absent
      assert_apply(host)
    end

    assert_events([:host_created], host)

    current_values = nil
    assert_nothing_raised {
      current_values = host.retrieve
    }

    # This was a hard bug to track down.
    assert_instance_of(String, current_values[host.property(:ip)])

    host[:ensure] = :absent
    assert_events([:host_removed], host)
  end

  def test_invalid_ipaddress
    host = mkhost

    assert_raise(Puppet::Error) {
      host[:ip] = "abc.def.ghi.jkl"
    }
  end

  def test_invalid_hostname
    host = mkhost

    assert_raise(Puppet::Error) {
      host[:name] = "!invalid.hostname.$PID$"
    }

    assert_raise(Puppet::Error) {
      host[:name] = "-boo"
    }

    assert_raise(Puppet::Error) {
      host[:name] = "boo-.ness"
    }

    assert_raise(Puppet::Error) {
      host[:name] = "boo..ness"
    }
  end

  def test_valid_hostname
    host = mkhost

    assert_nothing_raised {
      host[:name] = "yayness"
    }

    assert_nothing_raised {
      host[:name] = "yay-ness"
    }

    assert_nothing_raised {
      host[:name] = "yay.ness"
    }

    assert_nothing_raised {
      host[:name] = "yay.ne-ss"
    }

    assert_nothing_raised {
      host[:name] = "y.ay-ne-ss.com"
    }

    assert_nothing_raised {
      host[:name] = "y4y.n3-ss"
    }

    assert_nothing_raised {
      host[:name] = "y"
    }
  end
end
