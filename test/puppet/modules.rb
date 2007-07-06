#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

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

    def test_find_template
        templ = "testmod/templ.erb"
        assert_equal(File::join(Puppet[:templatedir], templ),
                     Puppet::Module::find_template(templ))

        templ_path = File::join(@varmods, "testmod",
                                Puppet::Module::TEMPLATES, "templ.erb")
        FileUtils::mkdir_p(File::dirname(templ_path))
        File::open(templ_path, "w") { |f| f.puts "Howdy" }

        assert_equal(templ_path, Puppet::Module::find_template(templ))

        mod = Puppet::Module::find(templ)
        assert_not_nil(mod)
        assert_equal(templ_path, mod.template(templ))
    end
end

# $Id$
