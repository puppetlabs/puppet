#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'etc'

class TestUser < Test::Unit::TestCase
    include PuppetTest

    p = Puppet::Type.type(:user).provide :fake, :parent => PuppetTest::FakeProvider do
        @name = :fake
        apimethods
        def create
            @ensure = :present
            @resource.send(:properties).each do |property|
                next if property.name == :ensure
                property.sync
            end
        end

        def delete
            @ensure = :absent
            @resource.send(:properties).each do |property|
                send(property.name.to_s + "=", :absent)
            end
        end

        def exists?
            if defined? @ensure and @ensure == :present
                true
            else
                false
            end
        end
    end

    FakeUserProvider = p

    @@fakeproviders[:group] = p

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

    def setup
        super
        Puppet::Type.type(:user).defaultprovider = FakeUserProvider
    end

    def teardown
        Puppet::Type.type(:user).defaultprovider = nil
        super
    end

    def mkuser(name)
        user = nil
        assert_nothing_raised {
            user = Puppet::Type.type(:user).new(
                :name => name,
                :comment => "Puppet Testing User",
                :gid => Puppet::Util::SUIDManager.gid,
                :shell => findshell(),
                :home => "/home/%s" % name
            )
        }

        assert(user, "Did not create user")

        return user
    end

    def attrtest_ensure(user)
        old = user.provider.ensure
        user[:ensure] = :absent

        comp = mk_catalog("ensuretest", user)
        assert_apply(user)
        assert(!user.provider.exists?, "User is still present")
        user[:ensure] = :present
        assert_events([:user_created], comp)
        assert(user.provider.exists?, "User is absent")
        user[:ensure] = :absent
        trans = assert_events([:user_removed], comp)

        user[:ensure] = old
        assert_apply(user)
    end

    def attrtest_comment(user)
        user.retrieve
        old = user.provider.comment
        user[:comment] = "A different comment"

        comp = mk_catalog("commenttest", user)

        assert_apply user

        assert_equal("A different comment", user.provider.comment,
            "Comment was not changed")

        user[:comment] = old
        assert_apply user
        assert_equal(old, user.provider.comment,
            "Comment was not reverted")
    end

    def attrtest_home(user)
        obj = nil
        comp = mk_catalog("hometest", user)

        old = user.provider.home
        assert_apply user

        user[:home] = "/tmp"

        assert_apply user

        assert_equal("/tmp", user.provider.home, "Home was not changed")
        user[:home] = old
        assert_apply user

        assert_equal(old, user.provider.home, "Home was not reverted")
    end

    def attrtest_shell(user)
        old = user.provider.shell
        comp = mk_catalog("shelltest", user)

        user[:shell] = old

        assert_apply(user)

        newshell = findshell(old)

        unless newshell
            $stderr.puts "Cannot find alternate shell; skipping shell test"
            return
        end

        user[:shell] = newshell

        assert_apply(user)

        user.retrieve
        assert_equal(newshell, user.provider.shell,
            "Shell was not changed")

        user.retrieve
        user[:shell] = old
        assert_apply user

        assert_equal(old, user.provider.shell, "Shell was not reverted")
    end

    def attrtest_uid(user)
        obj = nil
        comp = mk_catalog("uidtest", user)

        user.provider.uid = 1

        old = 1
        newuid = 1
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
            user[:uid] = newuid
        }

        assert_apply user

        assert_equal(newuid, user.provider.uid, "UID was not changed")
        user[:uid] = old
        assert_apply user

        assert_equal(old, user.provider.uid, "UID was not reverted")
    end

    def attrtest_groups(user)
        Etc.setgrent
        max = 0
        while group = Etc.getgrent
            if group.gid > max and group.gid < 5000
                max = group.gid
            end
        end

        groups = []
        main = []
        extra = []
        5.times do |i|
            i += 1
            name = "pptstgr%s" % i
            groups << name
            if i < 3
                main << name
            else
                extra << name
            end
        end

        assert(user[:membership] == :minimum, "Membership did not default correctly")

        assert_nothing_raised {
            user.retrieve
        }

        # Now add some of them to our user
        assert_nothing_raised {
            user[:groups] = extra
        }
        assert_nothing_raised {
            user.retrieve
        }

        assert_instance_of(String, user.property(:groups).should)

        # Some tests to verify that groups work correctly startig from nothing
        # Remove our user
        user[:ensure] = :absent
        assert_apply(user)

        assert_nothing_raised do
            user.retrieve
        end

        # And add it again
        user[:ensure] = :present
        assert_apply(user)

        # Make sure that the groups are a string, not an array
        assert(user.provider.groups.is_a?(String),
            "Incorrectly passed an array to groups")

        currentvalue = user.retrieve

        assert(currentvalue[user.property(:groups)], "Did not retrieve group list")

        list = currentvalue[user.property(:groups)]
        assert_equal(extra.sort, list.sort, "Group list is not equal")

        # Now set to our main list of groups
        assert_nothing_raised {
            user[:groups] = main
        }

        assert_equal((main + extra).sort, user.property(:groups).should.split(",").sort)

        currentvalue = nil
        assert_nothing_raised {
            currentvalue = user.retrieve
        }

        assert(!user.insync?(currentvalue), "User is incorrectly in sync")

        assert_apply(user)

        assert_nothing_raised {
            currentvalue = user.retrieve
        }

        # We're not managing inclusively, so it should keep the old group
        # memberships and add the new ones
        list = currentvalue[user.property(:groups)]
        assert_equal((main + extra).sort, list.sort, "Group list is not equal")

        assert_nothing_raised {
            user[:membership] = :inclusive
        }
        assert_nothing_raised {
            currentvalue = user.retrieve
        }

        assert(!user.insync?(currentvalue), "User is incorrectly in sync")

        assert_events([:user_created], user)
        assert_nothing_raised {
            currentvalue = user.retrieve
        }

        list = currentvalue[user.property(:groups)]
        assert_equal(main.sort, list.sort, "Group list is not equal")

        # Set the values a bit differently.
        user.property(:groups).should = list.sort { |a,b| b <=> a }

        assert(user.property(:groups).insync?(list.sort), "Groups property did not sort groups")

        user.delete(:groups)
    end

    def test_groups_list_must_not_contain_commas
        assert_raise(Puppet::Error) do
            Puppet::Type.type(:user).new :name => "luke", :groups => "root,adm"
        end
    end

    def test_autorequire
        file = tempfile()
        comp = nil
        user = nil
        group =nil
        home = nil
        ogroup = nil
        assert_nothing_raised {
            user = Puppet::Type.type(:user).new(
                :name => "pptestu",
                :home => file,
                :gid => "pptestg",
                :groups => "yayness"
            )
            home = Puppet::Type.type(:file).new(
                :path => file,
                :owner => "pptestu",
                :ensure => "directory"
            )
            group = Puppet::Type.type(:group).new(
                :name => "pptestg"
            )
            ogroup = Puppet::Type.type(:group).new(
                :name => "yayness"
            )
            comp = mk_catalog(user, group, home, ogroup)
        }

        rels = nil
        assert_nothing_raised() { rels = user.autorequire }

        assert(rels.detect { |r| r.source == group }, "User did not require group")
        assert(rels.detect { |r| r.source == ogroup }, "User did not require other groups")
        assert_nothing_raised() { rels = home.autorequire }
        assert(rels.detect { |r| r.source == user }, "Homedir did not require user")
    end

    def test_simpleuser
        name = "pptest"

        user = mkuser(name)

        comp = mk_catalog("usercomp", user)

        trans = assert_events([:user_created], comp, "user")

        assert_equal(user.should(:comment), user.provider.comment,
            "Comment was not set correctly")

        user[:ensure] = :absent
        assert_events([:user_removed], user)

        assert(! user.provider.exists?, "User did not get deleted")
    end

    def test_allusermodelproperties
        user = nil
        name = "pptest"

        user = mkuser(name)

        assert(! user.provider.exists?, "User %s is present" % name)

        comp = mk_catalog("usercomp", user)

        trans = assert_events([:user_created], comp, "user")

        user.retrieve
        assert_equal("Puppet Testing User", user.provider.comment,
            "Comment was not set")

        tests = Puppet::Type.type(:user).validproperties

        tests.each { |test|
            if self.respond_to?("attrtest_%s" % test)
                self.send("attrtest_%s" % test, user)
            else
                Puppet.err "Not testing attr %s of user" % test
            end
        }

        user[:ensure] = :absent
        assert_apply(user)
    end

    # Testing #455
    def test_autorequire_with_no_group_should
        user = Puppet::Type.type(:user).new(:name => "yaytest", :check => :all)
        catalog = mk_catalog(user)

        assert_nothing_raised do
            user.autorequire
        end

        user[:ensure] = :absent

        assert(user.property(:groups).insync?(nil),
            "Groups state considered out of sync with no :should value")
    end

    # Make sure the 'managehome' param can only be set when the provider
    # has that feature.  Uses a patch from #432.
    def test_managehome
        user = Puppet::Type.type(:user).new(:name => "yaytest", :check => :all)

        prov = user.provider

        home = false
        prov.class.meta_def(:manages_homedir?) { home }

        assert_nothing_raised("failed on false managehome") do
            user[:managehome] = false
        end

        assert_raise(Puppet::Error, "did not fail when managehome? is false") do
            user[:managehome] = true
        end

        home = true
        assert(prov.class.manages_homedir?, "provider did not enable homedir")
        assert_nothing_raised("failed when managehome is true") do
            user[:managehome] = true
        end
    end
end

