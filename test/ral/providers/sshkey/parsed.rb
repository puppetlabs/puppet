#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/puppettest')

require 'puppettest'
require 'puppettest/fileparsing'

class TestParsedSSHKey < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::FileParsing

  def setup
    super
    @provider = Puppet::Type.type(:sshkey).provider(:parsed)

    @oldfiletype = @provider.filetype
  end

  def teardown
    Puppet::Util::FileType.filetype(:ram).clear
    @provider.filetype = @oldfiletype
    @provider.clear
    super
  end

  def mkkey(name = "host.domain.com")
    if defined?(@pcount)
      @pcount += 1
    else
      @pcount = 1
    end
    args = {
      :name => name || "/fspuppet#{@pcount}",
      :key => "thisismykey#{@pcount}",
      :host_aliases => ["host1.domain.com","192.168.0.1"],
      :type => "dss",
      :ensure => :present
    }

    fakeresource = fakeresource(:sshkey, args[:name])

    key = @provider.new(fakeresource)
    args.each do |p,v|
      key.send(p.to_s + "=", v)
    end

    key
  end

  def test_keysparse
    fakedata("data/types/sshkey").each { |file|
      fakedataparse(file)
    }
  end

  def test_simplekey
    @provider.filetype = :ram
    file = @provider.default_target

    key = nil
    assert_nothing_raised do
      key = mkkey
    end

    assert(key, "did not create key")

    assert_nothing_raised do
      key.flush
    end

    assert(key.host_aliases, "No host_aliases set for key")

    hash = key.property_hash.dup
    text = @provider.target_object(file).read
    names = [key.name, key.host_aliases].flatten.join(",")

    assert_equal("#{names} #{key.type} #{key.key}\n", text)

    assert_nothing_raised do
      @provider.prefetch
    end

    hash.each do |p, v|
      next unless key.respond_to?(p)
      assert_equal(v, key.send(p), "#{p} did not match")
    end

    assert(key.name !~ /,/, "Aliases were not split out during parsing")
  end

  def test_hooks
    result = nil
    assert_nothing_raised("Could not call post hook") do
      result = @provider.parse_line("one,two type key")
    end
    assert_equal("one", result[:name], "Did not call post hook")
    assert_equal(%w{two}, result[:host_aliases], "Did not call post hook")


          assert_equal(
        "one,two type key",
      @provider.to_line(:record_type => :parsed,
      :name => "one",
      :host_aliases => %w{two},
      :type => "type",
        
      :key => "key"),
      "Did not use pre-hook when generating line"
    )
  end
end

