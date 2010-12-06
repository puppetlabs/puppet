#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'facter'

class TestSSHKey < Test::Unit::TestCase
  include PuppetTest
  def setup
    super
    # god i'm lazy
    @sshkeytype = Puppet::Type.type(:sshkey)

    @provider = @sshkeytype.defaultprovider

    # Make sure they are using the parsed provider
    unless @provider.name == :parsed
      @sshkeytype.defaultprovider = @sshkeytype.provider(:parsed)
    end

    cleanup do @sshkeytype.defaultprovider = nil end

    if @provider.respond_to?(:default_target)
      oldpath = @provider.default_target
      cleanup do
        @provider.default_target = oldpath
      end
      @provider.default_target = tempfile
    end
  end

  def teardown
    super
    @provider.clear if @provider.respond_to?(:clear)
  end

  def mkkey
    key = nil

    if defined?(@kcount)
      @kcount += 1
    else
      @kcount = 1
    end

    @catalog ||= mk_catalog


          key = @sshkeytype.new(
                
      :name => "host#{@kcount}.madstop.com",
      :key => "#{@kcount}AAAAB3NzaC1kc3MAAACBAMnhSiku76y3EGkNCDsUlvpO8tRgS9wL4Eh54WZfQ2lkxqfd2uT/RTT9igJYDtm/+UHuBRdNGpJYW1Nw2i2JUQgQEEuitx4QKALJrBotejGOAWxxVk6xsh9xA0OW8Q3ZfuX2DDitfeC8ZTCl4xodUMD8feLtP+zEf8hxaNamLlt/AAAAFQDYJyf3vMCWRLjTWnlxLtOyj/bFpwAAAIEAmRxxXb4jjbbui9GYlZAHK00689DZuX0EabHNTl2yGO5KKxGC6Esm7AtjBd+onfu4Rduxut3jdI8GyQCIW8WypwpJofCIyDbTUY4ql0AQUr3JpyVytpnMijlEyr41FfIb4tnDqnRWEsh2H7N7peW+8DWZHDFnYopYZJ9Yu4/jHRYAAACAERG50e6aRRb43biDr7Ab9NUCgM9bC0SQscI/xdlFjac0B/kSWJYTGVARWBDWug705hTnlitY9cLC5Ey/t/OYOjylTavTEfd/bh/8FkAYO+pWdW3hx6p97TBffK0b6nrc6OORT2uKySbbKOn0681nNQh4a6ueR3JRppNkRPnTk5c=",
      :type => "ssh-dss",
      :alias => ["192.168.0.#{@kcount}"],
        
      :catalog => @catalog
    )

    @catalog.add_resource(key)

    key
  end

  def test_instances
    list = nil
    assert_nothing_raised {
      list = Puppet::Type.type(:sshkey).instances
    }

    count = 0
    list.each do |h|
      count += 1
    end

    assert_equal(0, count, "Found sshkeys in empty file somehow")
  end

  def test_simplekey
    key = mkkey
    file = tempfile
    key[:target] = file
    key[:provider] = :parsed

    assert_apply(key)

    assert_events([], key, "created events on in-sync key")

    assert(key.provider.exists?, "Key did not get created")

    # Now create a new key object
    name = key.name
    key = nil

    key = @sshkeytype.new :name => name, :target => file, :provider => :parsed
    key.retrieve

    assert(key.provider.exists?, "key thinks it does not exist")

  end

  def test_removal
    sshkey = mkkey
    assert_nothing_raised {
      sshkey[:ensure] = :present
    }
    assert_events([:sshkey_created], sshkey)

    assert(sshkey.provider.exists?, "key was not created")
    assert_nothing_raised {
      sshkey[:ensure] = :absent
    }

    assert_events([:sshkey_removed], sshkey)
    assert(! sshkey.provider.exists?, "Key was not deleted")
    assert_events([], sshkey)
  end

  # Make sure changes actually modify the file.
  def test_modifyingfile
    keys = []
    names = []
    3.times {
      k = mkkey
      #h[:ensure] = :present
      #h.retrieve
      keys << k
      names << k.name
    }
    assert_apply(*keys)
    keys.clear

    @catalog.clear(true)
    @catalog = nil

    newkey = mkkey
    #newkey[:ensure] = :present
    names << newkey.name
    assert_apply(newkey)

    # Verify we can retrieve that info
    assert_nothing_raised("Could not retrieve after second write") {
      newkey.provider.prefetch
    }

    assert(newkey.provider.exists?, "Did not see key in file")
  end
end
