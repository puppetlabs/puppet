#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'etc'

class TestGroupProvider < Test::Unit::TestCase
  include PuppetTest
  def setup
    super
    @@tmpgroups = []
    @provider = nil
    assert_nothing_raised {
      @provider = Puppet::Type.type(:group).defaultprovider
    }

    assert(@provider, "Could not find default group provider")
    assert(@provider.name != :fake, "Got a fake provider")
  end

  def teardown
    super
    @@tmpgroups.each { |group|
      remove(group) unless missing?(group)
    }
  end

  def mkgroup(name, hash = {})
    fakeresource = stub 'group', :allowdupe? => false, :name => name
    fakeresource.stubs(:[]).returns nil
    fakeresource.stubs(:should).returns nil
    fakeresource.stubs(:[]).with(:name).returns name
    hash.each do |name, val|
      fakeresource.stubs(:should).with(name).returns val
      fakeresource.stubs(:[]).with(name).returns val
    end
    group = nil
    assert_nothing_raised {
      group = @provider.new(fakeresource)
    }
    assert(group, "Could not create provider group")

    group
  end

  case Facter["operatingsystem"].value
  when "Darwin"
    def missing?(group)
      output = %x{nidump -r /groups/#{group} / 2>/dev/null}.chomp

      return output == ""

      assert_equal("", output, "Group #{group} is present:\n#{output}")
    end

    def gid(name)
      %x{nireport / /groups name gid}.split("\n").each { |line|
        group, id = line.chomp.split(/\s+/)
        assert(id =~ /^-?\d+$/, "Group id #{id.inspect} for #{group} is not a number")
        if group == name
          return Integer(id)
        end
      }

      nil
    end

    def remove(group)
      system("niutil -destroy / /groups/#{group}")
    end
  else
    def missing?(group)
        obj = Etc.getgrnam(group)
        return false
    rescue ArgumentError
        return true
    end

    def gid(name)
      assert_nothing_raised {
        obj = Etc.getgrnam(name)
        return obj.gid
      }

      nil
    end

    def remove(group)
      system("groupdel #{group}")
    end
  end

  def groupnames
    %x{groups}.chomp.split(/ /)
  end

  def groupids
    Process.groups
  end

  def attrtest_ensure(group)
    old = group.ensure
    assert_nothing_raised {
      group.delete
    }

    assert(!group.exists?, "Group was not deleted")

    assert_nothing_raised {
      group.create
    }
    assert(group.exists?, "Group was not created")

    unless old == :present
      assert_nothing_raised {
        group.delete
      }
    end
  end

  def attrtest_gid(group)
    old = gid(group.name)

    newgid = old
    while true
      newgid += 1

      if newgid - old > 1000
        $stderr.puts "Could not find extra test UID"
        return
      end
      begin
        Etc.getgrgid(newgid)
      rescue ArgumentError => detail
        break
      end
    end

    assert_nothing_raised("Failed to change group id") {
      group.gid = newgid
    }

    curgid = nil
    assert_nothing_raised {
      curgid = gid(group.name)
    }

    assert_equal(newgid, curgid, "GID was not changed")
    # Refresh
    group.getinfo(true)
    assert_equal(newgid, group.gid, "Object got wrong gid")

    assert_nothing_raised("Failed to change group id") {
      group.gid = old
    }
  end

  # Iterate over each of our groups and try to grab the gid.
  def test_ownprovidergroups
    groupnames.each { |group|
      gobj = nil
      comp = nil
      fakeresource = fakeresource(:group, group)
      assert_nothing_raised {
        gobj = @provider.new(fakeresource)
      }

      assert(gobj.gid, "Failed to retrieve gid")
    }
  end

  if Puppet.features.root?
    def test_mkgroup
      gobj = nil
      comp = nil
      name = "pptestgr"
      assert(missing?(name), "Group #{name} is still present")
      group = mkgroup(name)

      @@tmpgroups << name

      assert(group.respond_to?(:addcmd), "no respondo?")
      assert_nothing_raised {
        group.create
      }
      assert(!missing?(name), "Group #{name} is missing")

      tests = Puppet::Type.type(:group).validproperties

      tests.each { |test|
        if self.respond_to?("attrtest_#{test}")
          self.send("attrtest_#{test}", group)
        else
          $stderr.puts "Not testing attr #{test} of group"
        end
      }

      assert_nothing_raised {
        group.delete
      }
    end

    # groupadd -o is broken in FreeBSD.
    unless Facter["operatingsystem"].value == "FreeBSD"
    def test_duplicateIDs
      group1 = mkgroup("group1", :gid => 125)

      @@tmpgroups << "group1"
      @@tmpgroups << "group2"
      # Create the first group
      assert_nothing_raised {
        group1.create
      }

      # Not all OSes fail here, so we can't test that it doesn't work with
      # it off, only that it does work with it on.
      group2 = mkgroup("group2", :gid => 125)
      group2.resource.stubs(:allowdupe?).returns true

      # Now create the second group
      assert_nothing_raised {
        group2.create
      }
      assert_equal(:present, group2.ensure, "Group did not get created")
    end
    end
  else
    $stderr.puts "Not running as root; skipping group creation tests."
  end

  def test_autogen
    provider = nil
    group = Puppet::Type.type(:group).new(:name => nonrootgroup.name)
    provider = group.provider
    assert(provider, "did not get provider")

    # Everyone should be able to autogenerate a uid
    assert_instance_of(Fixnum, provider.autogen(:gid))
  end
end

