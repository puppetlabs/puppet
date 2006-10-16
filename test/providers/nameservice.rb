#!/usr/bin/env ruby -I../lib -I../../lib

require 'puppettest'
require 'puppet'
require 'facter'

class TestNameServiceProvider < Test::Unit::TestCase
    include PuppetTest::FileTesting

    def test_option
        klass = Class.new(Puppet::Type::Provider::NameService)
        klass.model = Puppet::Type.type(:user)

        val = nil
        assert_nothing_raised {
            val = klass.option(:home, :flag)
        }

        assert_nil(val, "Got an option")

        assert_nothing_raised {
            klass.options :home, :flag => "-d"
        }
        assert_nothing_raised {
            val = klass.option(:home, :flag)
        }
        assert_equal("-d", val, "Got incorrect option")
    end
end

# $Id$
