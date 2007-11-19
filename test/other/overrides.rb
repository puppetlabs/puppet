#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppettest'

class TestOverrides < Test::Unit::TestCase
	include PuppetTest
    def mksubdirs(basedir, level)
        @@tmpfiles << basedir
        dir = basedir.dup

        (level + 1).times { |index|
            Dir.mkdir(dir)
            path = File.join(dir, "file")
            File.open(path, "w") { |f| f.puts "yayness" }
            dir = File.join(dir, index.to_s)
        }
    end

    def test_simpleoverride
        basedir = File.join(tmpdir(), "overridetesting")
        mksubdirs(basedir, 1)

        baseobj = nil
        basefile = File.join(basedir, "file")
        assert_nothing_raised("Could not create base obj") {
            baseobj = Puppet.type(:file).create(
                :title => "base",
                :path => basedir,
                :recurse => true,
                :mode => "755"
            )
        }

        subobj = nil
        subdir = File.join(basedir, "0")
        subfile = File.join(subdir, "file")
        assert_nothing_raised("Could not create sub obj") {
            subobj = Puppet.type(:file).create(
                :title => "sub",
                :path => subdir,
                :recurse => true,
                :mode => "644"
            )
        }

        assert_apply(baseobj, subobj)

        assert(File.stat(basefile).mode & 007777 == 0755)
        assert(File.stat(subfile).mode & 007777 == 0644)
    end

    def test_deepoverride
        basedir = File.join(tmpdir(), "deepoverridetesting")
        mksubdirs(basedir, 10)

        baseobj = nil
        assert_nothing_raised("Could not create base obj") {
            baseobj = Puppet.type(:file).create(
                :path => basedir,
                :recurse => true,
                :mode => "755"
            )
        }

        children = []
        files = {}
        subdir = basedir.dup
        mode = nil
        10.times { |index|
            next unless index % 3
            subdir = File.join(subdir, index.to_s)
            path = File.join(subdir, "file")
            if index % 2
                mode = "644"
                files[path] = 0644
            else
                mode = "750"
                files[path] = 0750
            end

            assert_nothing_raised("Could not create sub obj") {
                children << Puppet.type(:file).create(
                    :path => subdir,
                    :recurse => true,
                    :mode => mode
                )
            }
        }

        config = mk_configuration(baseobj, *children)

        assert_nothing_raised("Could not eval component") {
            config.apply
        }

        files.each { |path, mode|
            assert(FileTest.exists?(path), "File %s does not exist" % path)
            curmode = File.stat(path).mode & 007777
            assert(curmode == mode,
                "File %s was incorrect mode %o instead of %o" % [path, curmode, mode])
        }
    end
end

