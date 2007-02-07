#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

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

    def teardown
        super
        self.class.clear
    end

    def test_load
        dir = tempfile()
        $: << dir
        cleanup do
            $:.delete(dir)
        end

        Dir.mkdir(dir)

        rbdir = File.join(dir, "yayness")

        Dir.mkdir(rbdir)

        # An object for specifying autoload
        klass = self.class

        loader = nil
        assert_nothing_raised {
            loader = Puppet::Util::Autoload.new(klass, :yayness)
        }

        assert_equal(loader.object_id, Puppet::Util::Autoload[klass].object_id,
                    "Did not retrieve loader object by class")

        # Make sure we don't fail on missing files
        assert_nothing_raised {
            assert_equal(false, loader.load(:mything),
                        "got incorrect return on failed load")
        }

        # Now create a couple of files for testing
        path = File.join(rbdir, "mything.rb")
        mkfile(:mything, path)
        opath = File.join(rbdir, "othing.rb")
        mkfile(:othing, opath)

        # Now try to actually load it.
        assert_nothing_raised {
            assert_equal(true, loader.load(:mything),
                        "got incorrect return on failed load")
        }

        assert(loader.loaded?(:mything), "Not considered loaded")

        assert(klass.thing?(:mything),
                "Did not get loaded thing")

        # Now clear everything, and test loadall
        assert_nothing_raised {
            loader.clear
        }

        self.class.clear

        assert_nothing_raised {
            loader.loadall
        }

        [:mything, :othing].each do |thing|
            assert(loader.loaded?(thing), "#{thing.to_s} not considered loaded")

            assert(klass.thing?(thing),
                    "Did not get loaded #{thing.to_s}")
        end
    end

    # Make sure that autoload dynamically modifies $: with the libdir as
    # appropriate.
    def test_autoload_uses_libdir
        dir = Puppet[:libdir]
        unless FileTest.directory?(dir)
            Dir.mkdir(dir)
        end

        loader = File.join(dir, "test")
        Dir.mkdir(loader)
        name = "funtest"
        file = File.join(loader, "funtest.rb")
        File.open(file, "w") do |f|
            f.puts "$loaded = true"
        end

        auto = Puppet::Util::Autoload.new(self, "test")

        # Now make sure autoloading modifies $: as necessary
        assert(! $:.include?(dir), "search path already includes libdir")

        assert_nothing_raised do
            assert(auto.load("funtest"), "did not successfully load funtest")
        end
        assert($:.include?(dir), "libdir did not get added to search path")
    end
end
