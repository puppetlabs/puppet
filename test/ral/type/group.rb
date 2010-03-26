#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'etc'

class TestGroup < Test::Unit::TestCase
    include PuppetTest

    p = Puppet::Type.type(:group).provide :fake, :parent => PuppetTest::FakeProvider do
        @name = :fake
        apimethods :ensure, :gid

        def create
            @ensure = :present
        end

        def delete
            @ensure = :absent
        end

        def exists?
            if defined? @ensure and @ensure == :present
                true
            else
                false
            end
        end
    end

    FakeGroupProvider = p

    @@fakeproviders[:group] = p

    def setup
        super
        Puppet::Type.type(:group).defaultprovider = FakeGroupProvider
    end

    def teardown
        Puppet::Type.type(:group).defaultprovider = nil
        super
    end

    def mkgroup(name, hash = {})
        group = nil
        hash[:name] = name
        assert_nothing_raised {
            group = Puppet::Type.type(:group).new(hash)
        }

        return group
    end

    def groupnames
        %x{groups}.chomp.split(/ /)
    end

    def groupids
        Process.groups
    end

    def attrtest_ensure(group)
        group[:ensure] = :absent

        comp = mk_catalog("ensuretest", group)
        assert_apply(comp)
        assert_equal(:absent, group.provider.ensure,  "Group is still present")
        group[:ensure] = :present
        assert_events([:group_created], comp)
        assert_equal(:present, group.provider.ensure,  "Group is absent")
        group[:ensure] = :absent
        trans = assert_events([:group_removed], comp)
        assert_equal(:absent, group.provider.ensure,  "Group is present")
    end

    # This is a bit odd, since we're not actually doing anything on the machine.
    # Just make sure we can set the gid and that it will work correctly.
    def attrtest_gid(group)

        # Check the validation.
        assert_nothing_raised {
            group[:gid] = "15"
        }

        assert_equal(15, group.should(:gid),
                     "Did not convert gid to number")

        comp = mk_catalog(group)
        trans = assert_events([:group_modified], comp, "group")
        assert_equal(15, group.provider.gid, "GID was not changed")

        assert_nothing_raised {
            group[:gid] = 16
        }

        assert_equal(16, group.should(:gid),
                     "Did not keep gid as number")

        # Now switch to 16
        trans = assert_events([:group_modified], comp, "group")
        assert_equal(16, group.provider.gid, "GID was not changed")

        # And then rollback
        assert_rollback_events(trans, [:group_modified], "group")
        assert_equal(15, group.provider.gid, "GID was not changed")
    end

    def test_owngroups
        groupnames().each { |group|
            gobj = nil
            comp = nil
            assert_nothing_raised {
                gobj = Puppet::Type.type(:group).new(
                    :name => group,
                    :check => [:gid]
                )
            }

            # Set a fake gid
            gobj.provider.gid = rand(100)

            current_values = nil
            assert_nothing_raised {
                current_values = gobj.retrieve
            }

            assert(current_values[gobj.property(:gid)],
                   "Failed to retrieve gid")
        }
    end

    def test_mkgroup
        gobj = nil
        name = "pptestgr"

        assert_nothing_raised {
            gobj = Puppet::Type.type(:group).new(
                :name => name,
                :gid => 123
            )
        }
        gobj.finish

        trans = assert_events([:group_created], gobj, "group")

        assert(gobj.provider.exists?,
                "Did not create group")

        tests = Puppet::Type.type(:group).validproperties

        gobj.retrieve
        tests.each { |test|
            if self.respond_to?("attrtest_%s" % test)
                self.send("attrtest_%s" % test, gobj)
            else
                #$stderr.puts "Not testing attr %s of group" % test
            end
        }

        assert_rollback_events(trans, [:group_removed], "group")

        assert(! gobj.provider.exists?,
                "Did not delete group")
    end
end
