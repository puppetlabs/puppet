#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-11-07.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppettest'
require 'puppet/util/posix'

class TestPosixUtil < Test::Unit::TestCase
	include PuppetTest
	include Puppet::Util::POSIX
	
	def mk_posix_resource(type, obj)
	    field = idfield(type)
        res = Puppet::Type.type(type).create(
            :name => obj.name,
            field => obj.send(field)
        )
        res.setdefaults
        res
    end
	
	def test_get_posix_field
	    {:group => nonrootgroup, :passwd => nonrootuser}.each do |space, obj|
            id = Puppet::Util.idfield(space)
	        [obj.name, obj.send(id), obj.send(id).to_s].each do |test|
        	    value = nil
        	    assert_nothing_raised do
        	        value = get_posix_field(space, :name, test)
        	    end
        	    assert_equal(obj.name, value, "did not get correct value from get_posix_field")
    	    end
	    end
    end
    
    def test_gid_and_uid
        {:user => nonrootuser, :group => nonrootgroup}.each do |type, obj|
            method = idfield(type)
            # First make sure we get it back with both name and id with no object
            [obj.name, obj.send(method)].each do |value|
                assert_equal(obj.send(method), send(method, value))
            end
            
            # Now make a Puppet resource and make sure we get it from that.
            resource = mk_posix_resource(type, obj)
            
            [obj.name, obj.send(method)].each do |value|
                assert_equal(obj.send(method), send(method, value))
            end
        end
    end
    
    def test_util_methods
        assert(Puppet::Util.respond_to?(:uid), "util does not have methods")
    end
    
    # First verify we can convert a known user
    def test_gidbyname
        %x{groups}.split(" ").each { |group|
            gid = nil
            assert_nothing_raised {
                gid = Puppet::Util.gid(group)
            }

            assert(gid, "Could not retrieve gid for %s" % group)
        }
    end

    # Then verify we can retrieve a known group by gid
    def test_gidbyid
        %x{groups}.split(" ").each { |group|
            obj = Puppet.type(:group).create(
                :name => group,
                :check => [:gid]
            )
            obj.setdefaults
            current = obj.retrieve
            id = nil
            current.find { |prop, value| id = value if prop.name == :gid }
            gid = nil
            assert_nothing_raised {
                gid = Puppet::Util.gid(id)
            }

            assert(gid, "Could not retrieve gid for %s" % group)
            assert_equal(id, gid, "Got mismatched ids")
        }
    end

    # Finally, verify that we can find groups by id even if we don't
    # know them
    def test_gidbyunknownid
        gid = nil
        group = Puppet::Util::SUIDManager.gid
        assert_nothing_raised {
            gid = Puppet::Util.gid(group)
        }

        assert(gid, "Could not retrieve gid for %s" % group)
        assert_equal(group, gid, "Got mismatched ids")
    end

    def user
        require 'etc'
        unless defined? @user
            obj = Etc.getpwuid(Puppet::Util::SUIDManager.uid)
            @user = obj.name
        end
        return @user
    end

    # And do it all over again for users
    # First verify we can convert a known user
    def test_uidbyname
        user = user()
        uid = nil
        assert_nothing_raised {
            uid = Puppet::Util.uid(user)
        }

        assert(uid, "Could not retrieve uid for %s" % user)
        assert_equal(Puppet::Util::SUIDManager.uid, uid, "UIDs did not match")
    end

    # Then verify we can retrieve a known user by uid
    def test_uidbyid
        user = user()
        obj = Puppet.type(:user).create(
            :name => user,
            :check => [:uid]
        )
        obj.setdefaults
        obj.retrieve
        id = obj.provider.uid
        uid = nil
        assert_nothing_raised {
            uid = Puppet::Util.uid(id)
        }

        assert(uid, "Could not retrieve uid for %s" % user)
        assert_equal(id, uid, "Got mismatched ids")
    end

    # Finally, verify that we can find users by id even if we don't
    # know them
    def test_uidbyunknownid
        uid = nil
        user = Puppet::Util::SUIDManager.uid
        assert_nothing_raised {
            uid = Puppet::Util.uid(user)
        }

        assert(uid, "Could not retrieve uid for %s" % user)
        assert_equal(user, uid, "Got mismatched ids")
    end
end

