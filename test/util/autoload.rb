#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppet/util/autoload'
require 'puppettest'

class TestAutoload < Test::Unit::TestCase
	include PuppetTest
    @things = []
    def self.newthing(name)
        @things << name
    end

    def self.thing?(name)
        @things.include? name
    end

    def self.clear
        @things.clear
    end

    def mkfile(name, path)
        # Now create a file to load
        File.open(path, "w") do |f|
            f.puts %{
TestAutoload.newthing(:#{name.to_s})
            }
        end
    end

    def mk_loader(name)
        dir = tempfile()
        $: << dir
        cleanup do
            $:.delete(dir)
        end

        Dir.mkdir(dir)

        rbdir = File.join(dir, name.to_s)

        Dir.mkdir(rbdir)

        loader = nil
        assert_nothing_raised {
            loader = Puppet::Util::Autoload.new(self.class, name)
        }
        return rbdir, loader
    end

    def test_load
        dir, loader = mk_loader(:yayness)

        assert_equal(loader.object_id, Puppet::Util::Autoload[self.class].object_id,
                    "Did not retrieve loader object by class")

        # Make sure we don't fail on missing files
        assert_nothing_raised {
            assert_equal(false, loader.load(:mything),
                        "got incorrect return on failed load")
        }

        # Now create a couple of files for testing
        path = File.join(dir, "mything.rb")
        mkfile(:mything, path)
        opath = File.join(dir, "othing.rb")
        mkfile(:othing, opath)

        # Now try to actually load it.
        assert_nothing_raised {
            assert_equal(true, loader.load(:mything),
                        "got incorrect return on load")
        }

        assert(loader.loaded?(:mything), "Not considered loaded")

        assert(self.class.thing?(:mything),
                "Did not get loaded thing")

        self.class.clear

        [:mything, :othing].each do |thing|
            loader.load(thing)
            assert(loader.loaded?(thing), "#{thing.to_s} not considered loaded")
            assert(loader.loaded?("%s.rb" % thing), "#{thing.to_s} not considered loaded with .rb")
            assert(Puppet::Util::Autoload.loaded?("yayness/%s" % thing), "%s not considered loaded by the main class" % thing)
            assert(Puppet::Util::Autoload.loaded?("yayness/%s.rb" % thing), "%s not considered loaded by the main class with .rb" % thing)

            assert(self.class.thing?(thing),
                    "Did not get loaded #{thing.to_s}")
        end
    end

    # This tests #1027, which was caused by using the unqualified
    # path for requires, which was initially done so that the kernel
    # would keep track of which files got loaded.
    def test_require_uses_full_path
        loadname = "testing"
        loader = Puppet::Util::Autoload.new(self.class, loadname)

        basedir = "/some/dir"
        dir = File.join(basedir, loadname)
        loader.expects(:searchpath).returns(dir)

        subname = "instance"

        file = File.join(dir, subname) + ".rb"

        Dir.expects(:glob).with("#{dir}/*.rb").returns(file)

        Kernel.expects(:require).with(file)
        loader.loadall
    end
end
