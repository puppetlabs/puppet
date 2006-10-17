#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest'

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

    # Test the different age iterations.
    def test_age_conversions
        tidy = Puppet::Type.newtidy :path => tempfile(), :age => "1m"

        convertors = {
            :second => 1,
            :minute => 60
        }

        convertors[:hour] = convertors[:minute] * 60
        convertors[:day] = convertors[:hour] * 24
        convertors[:week] = convertors[:day] * 7

        # First make sure we default to days
        assert_nothing_raised do
            tidy[:age] = "2"
        end

        assert_equal(2 * convertors[:day], tidy[:age],
            "Converted 2 wrong")

        convertors.each do |name, number|
            init = name.to_s[0..0] # The first letter
            [0, 1, 5].each do |multi|
                [init, init.upcase].each do |letter|
                    age = multi.to_s + letter.to_s
                    assert_nothing_raised do
                        tidy[:age] = age
                    end

                    assert_equal(multi * convertors[name], tidy[:age],
                        "Converted %s wrong" % age)
                end
            end
        end
    end

    def test_size_conversions
        convertors = {
            :b => 0,
            :kb => 1,
            :mb => 2,
            :gb => 3
        }

        tidy = Puppet::Type.newtidy :path => tempfile(), :age => "1m"

        # First make sure we default to kb
        assert_nothing_raised do
            tidy[:size] = "2"
        end

        assert_equal(2048, tidy[:size],
            "Converted 2 wrong")

        convertors.each do |name, number|
            init = name.to_s[0..0] # The first letter
            [0, 1, 5].each do |multi|
                [init, init.upcase].each do |letter|
                    size = multi.to_s + letter.to_s
                    assert_nothing_raised do
                        tidy[:size] = size
                    end

                    total = multi
                    number.times do total *= 1024 end

                    assert_equal(total, tidy[:size],
                        "Converted %s wrong" % size)
                end
            end
        end
    end

    def test_agetest
        tidy = Puppet::Type.newtidy :path => tempfile(), :age => "1m"

        state = tidy.state(:tidyup)

        # Set it to something that should be fine
        state.is = [Time.now.to_i - 5, 50]

        assert(state.insync?, "Tried to tidy a low age")

        # Now to something that should fail
        state.is = [Time.now.to_i - 120, 50]

        assert(! state.insync?, "Incorrectly skipped tidy")
    end

    def test_sizetest
        tidy = Puppet::Type.newtidy :path => tempfile(), :size => "1k"

        state = tidy.state(:tidyup)

        # Set it to something that should be fine
        state.is = [5, 50]

        assert(state.insync?, "Tried to tidy a low size")

        # Now to something that should fail
        state.is = [120, 2048]

        assert(! state.insync?, "Incorrectly skipped tidy")
    end

    # Make sure we can remove different types of files
    def test_tidytypes
        path = tempfile()
        tidy = Puppet::Type.newtidy :path => path, :size => "1b", :age => "1s"

        # Start with a file
        File.open(path, "w") { |f| f.puts "this is a test" }
        assert_events([:file_tidied], tidy)
        assert(! FileTest.exists?(path), "File was not removed")

        # Then a link
        dest = tempfile
        File.open(dest, "w") { |f| f.puts "this is a test" }
        File.symlink(dest, path)
        assert_events([:file_tidied], tidy)
        assert(! FileTest.exists?(path), "Link was not removed")
        assert(FileTest.exists?(dest), "Destination was removed")

        # And a directory
        Dir.mkdir(path)
        tidy.is = [:tidyup, [Time.now - 1024, 1]]
        tidy[:rmdirs] = true
        assert_events([:file_tidied], tidy)
        assert(! FileTest.exists?(path), "File was not removed")
    end
end

# $Id$
