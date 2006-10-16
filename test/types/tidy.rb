#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'

# $Id$

class TestTidy < Test::Unit::TestCase
    include PuppetTest::FileTesting
    def mktmpfile
        # because luke's home directory is on nfs, it can't be used for testing
        # as root
        tmpfile = tempfile()
        File.open(tmpfile, "w") { |f| f.puts rand(100) }
        @@tmpfiles.push tmpfile
        return tmpfile
    end

    def mktmpdir
        dir = File.join(tmpdir(), "puppetlinkdir")
        unless FileTest.exists?(dir)
            Dir.mkdir(dir)
        end
        @@tmpfiles.push dir
        return dir
    end

    def test_simpletidy
        dir = mktmpdir
        file = File.join(dir, "tidytesting")
        File.open(file, "w") { |f|
            f.puts rand(100)
        }

        tidy = Puppet.type(:tidy).create(
            :name => dir,
            :size => "1b",
            :recurse => true
        )
        comp = newcomp("tidytesting", tidy)
        comp.finalize

        trans = nil
        assert_events([:file_tidied], comp)
        assert(!FileTest.exists?(file), "Tidied file still exists")
    end

    def test_tidydirs
        dir = mktmpdir
        file = File.join(dir, "tidytesting")
        File.open(file, "w") { |f|
            f.puts rand(100)
        }

        tidy = Puppet.type(:tidy).create(
            :name => dir,
            :size => "1b",
            :age => "1s",
            :rmdirs => true,
            :recurse => true
        )


        sleep(2)
        assert_events([:file_tidied, :file_tidied], tidy)

        assert(!FileTest.exists?(file), "Tidied %s still exists" % file)
        assert(!FileTest.exists?(dir), "Tidied %s still exists" % dir)

    end

    def disabled_test_recursion
        source = mktmpdir()
        FileUtils.cd(source) {
            mkranddirsandfiles()
        }

        link = nil
        assert_nothing_raised {
            link = newlink(:target => source, :recurse => true)
        }
        comp = newcomp("linktest",link)
        cycle(comp)

        path = link.name
        list = file_list(path)
        FileUtils.cd(path) {
            list.each { |file|
                unless FileTest.directory?(file)
                    assert(FileTest.symlink?(file))
                    target = File.readlink(file)
                    assert_equal(target,File.join(source,file.sub(/^\.\//,'')))
                end
            }
        }
    end
end
