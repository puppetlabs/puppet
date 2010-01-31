#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-12-12.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../lib/puppettest'

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
        obj = @purgetype.create :name => "purger%s" % @purgenum
        $purgemembers[obj[:name]] = obj
        if managed
            obj[:fake] = "testing"
        end
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

    def test_purge
        # Create a purgeable type
        mkpurgertype

        purger = nil
        assert_nothing_raised do
            purger = @type.new :name => "purgetest", :noop => true, :loglevel => :warning
        end
        purger.catalog = Puppet::Resource::Catalog.new
        assert(purger, "did not get purger manager")
        add_purge_lister()

        assert_equal($purgemembers.values.sort, @purgetype.instances.sort)

        # and it should now succeed
        assert_nothing_raised do
            purger[:purge] = true
        end
        assert(purger.purge?, "purge boolean was not enabled")

        # Okay, now let's try doing some purging, yo
        managed = []
        unmanned = []
        3.times { managed << mk_purger(true) } # 3 managed
        3.times { unmanned << mk_purger(false) } # 3 unmanaged

        managed.each do |m|
            assert(m.managed?, "managed resource was not considered managed")
        end
        unmanned.each do |u|
            assert(! u.managed?, "unmanaged resource was considered managed")
        end

        # First make sure we get nothing back when purge is false
        genned = nil
        purger[:purge] = false
        assert_nothing_raised do
            genned = purger.generate
        end
        assert_equal([], genned, "Purged even when purge is false")

        # Now make sure we can purge
        purger[:purge] = true
        assert_nothing_raised do
            genned = purger.generate
        end
        assert(genned, "Did not get any generated resources")

        genned.each do |res|
            assert(res.purging, "did not mark resource for purging")
        end
        assert(! genned.empty?, "generated resource list was empty")

        # Now make sure the generate method only finds the unmanaged resources
        assert_equal(unmanned.collect { |r| r.title }.sort, genned.collect { |r| r.title },
            "Did not return correct purge list")

        # Now make sure our metaparams carried over
        genned.each do |res|
            [:noop, :loglevel].each do |param|
                assert_equal(purger[param], res[param], "metaparam %s did not carry over" % param)
            end
        end
    end

    # Part of #408.
    def test_check
        # First check a non-user
        res = Puppet::Type.type(:resources).new :name => :package
        assert_nil(res[:unless_system_user], "got bad default for package")


        assert_nothing_raised {
            assert(res.check("A String"), "String failed check")
            assert(res.check(Puppet::Type.type(:file).new(:path => tempfile())), "File failed check")
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

        if low
            assert(! res.check(@user.create(:name => low)), "low user %s passed check" % low)
        end
        if high
            res[:unless_system_user] = 50
            assert(res.check(@user.create(:name => high)), "high user %s failed check" % high)
        end
    end
end

