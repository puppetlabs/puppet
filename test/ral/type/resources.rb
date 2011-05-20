#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-12-12.
#  Copyright (c) 2006. All rights reserved.

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'

class TestResources < Test::Unit::TestCase
  include PuppetTest

  def add_purge_lister
    # Now define the list method
    class << @purgetype
      def instances
        $purgemembers.values
      end
    end
  end

  def mk_purger(managed = false)
    @purgenum ||= 0
    @purgenum += 1
    obj = @purgetype.create :name => "purger#{@purgenum}"
    $purgemembers[obj[:name]] = obj
    obj[:fake] = "testing" if managed
    obj
  end

  def mkpurgertype
    # Create a purgeable type
    $purgemembers = {}
    @purgetype = Puppet::Type.newtype(:purgetest) do
      newparam(:name, :namevar => true) {}
      newproperty(:ensure) do
        newvalue(:absent) do
          $purgemembers[@parent[:name]] = @parent
        end
        newvalue(:present) do
          $purgemembers.delete(@parent[:name])
        end
      end
      newproperty(:fake) do
        def sync
          :faked
        end
      end
    end
    cleanup do
      Puppet::Type.rmtype(:purgetest)
    end
  end

  def setup
    super
    @type = Puppet::Type.type(:resources)
  end

  # Part of #408.
  def test_check
    # First check a non-user
    res = Puppet::Type.type(:resources).new :name => :package
    assert_nil(res[:unless_system_user], "got bad default for package")


    assert_nothing_raised {
      assert(res.check("A String"), "String failed check")
      assert(res.check(Puppet::Type.type(:file).new(:path => tempfile)), "File failed check")
      assert(res.check(Puppet::Type.type(:user).new(:name => "yayness")), "User failed check in package")
    }

    # Now create a user manager
    res = Puppet::Type.type(:resources).new :name => :user

    # Make sure the default is 500
    assert_equal(500, res[:unless_system_user], "got bad default")

    # Now make sure root fails the test
    @user = Puppet::Type.type(:user)
    assert_nothing_raised {
      assert(! res.check(@user.create(:name => "root")), "root passed check")
      assert(! res.check(@user.create(:name => "nobody")), "nobody passed check")
    }

    # Now find a user between 0 and the limit
    low = high = nil
    Etc.passwd { |entry|
      if ! low and (entry.uid > 10 and entry.uid < 500)
        low = entry.name
      else
        # We'll reset the limit, since we can't really guarantee that
        # there are any users with uid > 500
        if ! high and entry.uid > 100 and ! res.system_users.include?(entry.name)
          high = entry.name
          break
        end
      end
    }

    assert(! res.check(@user.create(:name => low)), "low user #{low} passed check") if low
    if high
      res[:unless_system_user] = 50
      assert(res.check(@user.create(:name => high)), "high user #{high} failed check")
    end
  end
end

