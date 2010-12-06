#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'

#require 'facter'
#
#class TestPort < Test::Unit::TestCase
#   include PuppetTest
#
#    def setup
#        super
#        @porttype = Puppet::Type.type(:port)
#
#        @provider = @porttype.defaultprovider
#
#        # Make sure they are using the parsed provider
#        unless @provider.name == :parsed
#            @porttype.defaultprovider = @porttype.provider(:parsed)
#        end
#
#        cleanup do @porttype.defaultprovider = nil end
#
#        if @provider.respond_to?(:default_target)
#            oldpath = @provider.default_target
#            cleanup do
#                @provider.default_target = oldpath
#            end
#            @provider.default_target = tempfile
#        end
#    end
#
#    def mkport
#        port = nil
#
#        if defined?(@pcount)
#            @pcount += 1
#        else
#            @pcount = 1
#        end
#        assert_nothing_raised {
#            port = Puppet::Type.type(:port).new(
#                :name => "puppet#{@pcount}",
#                :number => "813#{@pcount}",
#                :protocols => "tcp",
#                :description => "The port that Puppet runs on",
#                :alias => "coolness#{@pcount}"
#            )
#        }
#
#        return port
#    end
#
#    def test_list
#        assert_nothing_raised {
#            Puppet::Type.type(:port).list
#        }
#
#        count = 0
#        @porttype.each do |h|
#            count += 1
#        end
#
#        assert_equal(0, count, "Found hosts in empty file somehow")
#
#        dns = @porttype["domain"]
#        assert(dns, "Did not retrieve dns service")
#    end
#
#    def test_simpleport
#        host = nil
#
#        port = mkport
#
#        assert_apply(port)
#        assert_nothing_raised {
#            port.retrieve
#        }
#
#        assert(port.provider.exists?, "Port did not get created")
#    end
#
#    def test_moddingport
#        port = nil
#        port = mkport
#
#        assert_events([:port_created], port)
#
#        port.retrieve
#
#        port[:protocols] = %w{tcp udp}
#
#        assert_events([:port_changed], port)
#    end
#
#    def test_multivalues
#        port = mkport
#        assert_raise(Puppet::Error) {
#            port[:protocols] = "udp tcp"
#        }
#        assert_raise(Puppet::Error) {
#            port[:alias] = "puppetmasterd yayness"
#        }
#    end
#
#    def test_removal
#        port = mkport
#        assert_nothing_raised {
#            port[:ensure] = :present
#        }
#        assert_events([:port_created], port)
#        assert_events([], port)
#
#        assert(port.provider.exists?, "port was not created")
#        assert_nothing_raised {
#            port[:ensure] = :absent
#        }
#
#        assert_events([:port_removed], port)
#        assert(! port.provider.exists?, "port was not removed")
#        assert_events([], port)
#    end
#
#    def test_addingproperties
#        port = mkport
#        assert_events([:port_created], port)
#
#        port.delete(:alias)
#        assert(! port.property(:alias))
#        assert_events([:port_changed], port)
#
#        assert_nothing_raised {
#            port.retrieve
#        }
#
#        assert_equal(:present, port.is(:ensure))
#
#        assert_equal(:absent, port.is(:alias))
#
#        port[:alias] = "yaytest"
#        assert_events([:port_changed], port)
#        port.retrieve
#        assert(port.property(:alias).is == ["yaytest"])
#    end
#end

