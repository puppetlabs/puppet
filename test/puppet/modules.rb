#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'

class TestModules < Test::Unit::TestCase
	include PuppetTest

    def setup
        super
        @varmods = File::join(Puppet[:vardir], "modules")
        FileUtils::mkdir_p(@varmods)
    end

    def test_modulepath
        Puppet[:modulepath] = "$vardir/modules:/no/such/path/anywhere:.::"
        assert_equal([ @varmods ], Puppet::Module.modulepath)
    end

    def test_find
        assert_nil(Puppet::Module::find("/tmp"))

        file = "testmod/something"
        assert_nil(Puppet::Module::find(file))

        path = File::join(@varmods, "testmod")
        FileUtils::mkdir_p(path)

        mod = Puppet::Module::find("testmod")
        assert_not_nil(mod)
        assert_equal("testmod", mod.name)
        assert_equal(path, mod.path)

        mod = Puppet::Module::find(file)
        assert_not_nil(mod)
        assert_equal("testmod", mod.name)
        assert_equal(path, mod.path)
    end
end
