#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppettest/support/utils'

class TestUserProvider < Test::Unit::TestCase
  include PuppetTest::Support::Utils
  include PuppetTest::FileTesting

  def setup
    super
    setme
    @@tmpusers = []
    @provider = nil
    assert_nothing_raised {
      @provider = Puppet::Type.type(:user).defaultprovider
    }

    assert(@provider, "Could not find default user provider")

  end

  def teardown
    @@tmpusers.each { |user|
      remove(user) unless missing?(user)
    }
    super
  end

  case Facter["operatingsystem"].value
  when "Darwin"
    def missing?(user)
      output = %x{nidump -r /users/#{user} / 2>/dev/null}.chomp

      return output == ""

      assert_equal("", output, "User #{user} is present:\n#{output}")
    end

    def current?(param, user)
      property = Puppet::Type.type(:user).properties.find { |st|
        st.name == param
      }

      prov = Puppet::Type.type(:user).defaultprovider
      output = prov.report(param)
      output.each { |hash|
        if hash[:name] == user.name
          val = hash[param]
          if val =~ /^[-0-9]+$/
            return Integer(val)
          else
            return val
          end
        end
      }

      nil
    end

    def remove(user)
      system("niutil -destroy / /users/#{user}")
    end
  else
    def missing?(user)
        obj = Etc.getpwnam(user)
        return false
    rescue ArgumentError
        return true
    end

    def current?(param, user)
      property = Puppet::Type.type(:user).properties.find { |st|
        st.name == param
      }

      assert_nothing_raised {
        obj = Etc.getpwnam(user.name)
        return obj.send(user.posixmethod(param))
      }

      nil
    end

    def remove(user)
      system("userdel #{user}")
    end
  end


  def eachproperty
    Puppet::Type.type(:user).validproperties.each do |property|
      yield property
    end
  end

  def findshell(old = nil)
    %w{/bin/sh /bin/bash /sbin/sh /bin/ksh /bin/zsh /bin/csh /bin/tcsh
      /usr/bin/sh /usr/bin/bash /usr/bin/ksh /usr/bin/zsh /usr/bin/csh
      /usr/bin/tcsh}.find { |shell|
        if old
          FileTest.exists?(shell) and shell != old
        else
          FileTest.exists?(shell)
        end
    }
  end

  def fakedata(name, param)
    case param
    when :name; name
    when :ensure; :present
    when :comment; "Puppet's Testing User #{name}" # use a single quote a la #375
    when :gid; nonrootgroup.gid
    when :shell; findshell
    when :home; "/home/#{name}"
    else
      return nil
    end
  end

  def fakeresource(*args)
    resource = super

    # Set boolean methods as necessary.
    class << resource
      def allowdupe?
        self[:allowdupe]
      end
      def managehome?
        self[:managehome]
      end
    end
    resource
  end

  def mkuser(name)
    fakeresource = fakeresource(:user, name)
    user = nil
    assert_nothing_raised {
      user = @provider.new(fakeresource)
    }
    assert(user, "Could not create provider user")

    user
  end

  def test_list
    names = nil
    assert_nothing_raised {
      names = @provider.listbyname
    }

    assert(names.length > 0, "Listed no users")

    # Now try it by object
    assert_nothing_raised {
      names = @provider.instances
    }
    assert(names.length > 0, "Listed no users as objects")

    names.each do |obj|
      assert_instance_of(@provider, obj)
    end
  end

  def test_infocollection
    fakeresource = fakeresource(:user, @me)

    user = nil
    assert_nothing_raised {
      user = @provider.new(fakeresource)
    }
    assert(user, "Could not create user provider")

    Puppet::Type.type(:user).validproperties.each do |property|
      next if property == :ensure
      # This is mostly in place for the 'password' stuff.
      next unless user.class.supports_parameter?(property) and Puppet.features.root?
      val = nil
      assert_nothing_raised {
        val = user.send(property)
      }


        assert(
          val != :absent,

          "Property #{property} is missing")

      assert(val, "Did not get value for #{property}")
    end
  end

  def test_exists
    user = mkuser("nosuchuserok")


      assert(
        ! user.exists?,

        "Fake user exists?")

    user = mkuser(@me)

      assert(
        user.exists?,

        "I don't exist?")
  end

  def attrtest_ensure(user)
    old = user.ensure
    assert_nothing_raised {
      user.delete
    }

    assert(missing?(user.name), "User is still present")
    assert_nothing_raised {
      user.create
    }
    assert(!missing?(user.name), "User is absent")
    assert_nothing_raised {
      user.delete
    }

    unless old == :absent
      user.create
    end
  end

  def attrtest_comment(user)
    old = user.comment

    newname = "Billy O'Neal" # use a single quote, a la #372
    assert_nothing_raised {
      user.comment = newname
    }


      assert_equal(
        newname, current?(:comment, user),

      "Comment was not changed")

    assert_nothing_raised {
      user.comment = old
    }


      assert_equal(
        old, current?(:comment, user),

      "Comment was not reverted")
  end

  def attrtest_home(user)
    old = current?(:home, user)

    assert_nothing_raised {
      user.home = "/tmp"
    }

    assert_equal("/tmp", current?(:home, user), "Home was not changed")
    assert_nothing_raised {
      user.home = old
    }

    assert_equal(old, current?(:home, user), "Home was not reverted")
  end

  def attrtest_shell(user)
    old = current?(:shell, user)

    newshell = findshell(old)

    unless newshell
      $stderr.puts "Cannot find alternate shell; skipping shell test"
      return
    end

    assert_nothing_raised {
      user.shell = newshell
    }


      assert_equal(
        newshell, current?(:shell, user),

      "Shell was not changed")

    assert_nothing_raised {
      user.shell = old
    }

    assert_equal(old, current?(:shell, user), "Shell was not reverted")
  end

  def attrtest_gid(user)
    old = current?(:gid, user)

    newgroup = %w{nogroup nobody staff users daemon}.find { |gid|
      begin
        group = Etc.getgrnam(gid)
        rescue ArgumentError => detail
          next
        end
        old != group.gid
    }
    group = Etc.getgrnam(newgroup)

    unless newgroup
      $stderr.puts "Cannot find alternate group; skipping gid test"
      return
    end

    # Stupid DirectoryServices
    if Facter.value(:operatingsystem) == "Darwin"
      assert_raise(ArgumentError, "gid allowed a non-integer value") do
        user.gid = group.name
      end
    end

    assert_nothing_raised("Failed to specify group by id") {
      user.gid = group.gid
    }

    assert_equal(group.gid, current?(:gid,user), "GID was not changed")

    assert_nothing_raised("Failed to change back to old gid") {
      user.gid = old
    }
  end

  def attrtest_uid(user)
    old = current?(:uid, user)

    newuid = old
    while true
      newuid += 1

      if newuid - old > 1000
        $stderr.puts "Could not find extra test UID"
        return
      end
      begin
        newuser = Etc.getpwuid(newuid)
      rescue ArgumentError => detail
        break
      end
    end

    assert_nothing_raised("Failed to change user id") {
      user.uid = newuid
    }

    assert_equal(newuid, current?(:uid, user), "UID was not changed")

    assert_nothing_raised("Failed to change user id") {
      user.uid = old
    }
    assert_equal(old, current?(:uid, user), "UID was not changed back")
  end

  def attrtest_groups(user)
    Etc.setgrent
    max = 0
    while group = Etc.getgrent
      max = group.gid if group.gid > max and group.gid < 5000
    end

    groups = []
    main = []
    extra = []
    5.times do |i|
      i += 1
      name = "pptstgr#{i}"

        tmpgroup = Puppet::Type.type(:group).new(

          :name => name,

          :gid => max + i
      )

      groups << tmpgroup

      cleanup do
        tmpgroup.provider.delete if tmpgroup.provider.exists?
      end

      if i < 3
        main << name
      else
        extra << name
      end
    end

    # Create our test groups
    assert_apply(*groups)

    # Now add some of them to our user
    assert_nothing_raised {
      user.resource[:groups] = extra.join(",")
    }

    # Some tests to verify that groups work correctly startig from nothing
    # Remove our user
    user.delete

    # And add it again
    user.create

    # Make sure that the group list is added at creation time.
    # This is necessary because we don't have default fakedata for groups.
    assert(user.groups, "Did not retrieve group list")

    list = user.groups.split(",")
    assert_equal(extra.sort, list.sort, "Group list was not set at creation time")

    # Now set to our main list of groups
    assert_nothing_raised {
      user.groups = main.join(",")
    }

    list = user.groups.split(",")
    assert_equal(main.sort, list.sort, "Group list is not equal")
  end

  if Puppet.features.root?
    def test_simpleuser
      name = "pptest"

      assert(missing?(name), "User #{name} is present")

      user = mkuser(name)

      eachproperty do |property|
        if val = fakedata(user.name, property)
          user.resource[property] = val
        end
      end

      @@tmpusers << name

      assert_nothing_raised {
        user.create
      }

      assert_equal("Puppet's Testing User pptest",
        user.comment,
        "Comment was not set")

      assert_nothing_raised {
        user.delete
      }

      assert(missing?(user.name), "User was not deleted")
    end

    def test_alluserproperties
      user = nil
      name = "pptest"

      assert(missing?(name), "User #{name} is present")

      user = mkuser(name)

      eachproperty do |property|
        if val = fakedata(user.name, property)
          user.resource[property] = val
        end
      end

      @@tmpusers << name

      assert_nothing_raised {
        user.create
      }
      assert_equal("Puppet's Testing User pptest", user.comment,
        "Comment was not set")

      tests = Puppet::Type.type(:user).validproperties

      just = nil
      tests.each { |test|
        if self.respond_to?("attrtest_#{test}")
          self.send("attrtest_#{test}", user)
        else
          Puppet.err "Not testing attr #{test} of user"
        end
      }

      assert_nothing_raised {
        user.delete
      }
    end

    # This is a weird method that shows how annoying the interface between
    # types and providers is.  Grr.
    def test_duplicateIDs
      user1 = mkuser("user1")
      user1.create
      user1.uid = 125
      user2 = mkuser("user2")
      user2.resource[:uid] = 125

      cleanup do
        user1.delete
        user2.delete
      end

      # Not all OSes fail here, so we can't test that it doesn't work with
      # it off, only that it does work with it on.
      assert_nothing_raised {
        user2.resource[:allowdupe] = :true
      }
      assert_nothing_raised { user2.create }

        assert_equal(
          :present, user2.ensure,

            "User did not get created")
    end
  else
    $stderr.puts "Not root; skipping user creation/modification tests"
  end

  # Here is where we test individual providers
  def test_useradd_flags
    useradd = nil
    assert_nothing_raised {
      useradd = Puppet::Type.type(:user).provider(:useradd)
    }
    assert(useradd, "Did not retrieve useradd provider")

    user = nil
    assert_nothing_raised {
      fakeresource = fakeresource(:user, @me)
      user = useradd.new(fakeresource)
    }


      assert_equal(
        "-d", user.send(:flag, :home),

          "Incorrect home flag")


          assert_equal(
            "-s", user.send(:flag, :shell),

          "Incorrect shell flag")
  end

  def test_autogen
    provider = nil
    user = Puppet::Type.type(:user).new(:name => nonrootuser.name)
    provider = user.provider
    assert(provider, "did not get provider")

    # Everyone should be able to autogenerate a uid
    assert_instance_of(Fixnum, provider.autogen(:uid))

    # If we're Darwin, then we should get results, but everyone else should
    # get nil
    darwin = (Facter.value(:operatingsystem) == "Darwin")

    should = {
      :comment => user[:name].capitalize,
      :home => "/var/empty",
      :shell => "/usr/bin/false"
    }

    should.each do |param, value|
      if darwin
        assert_equal(value, provider.autogen(param), "did not autogen #{param} for darwin correctly")
      else
        assert_nil(provider.autogen(param), "autogenned #{param} for non-darwin os")
      end
    end
  end
end

