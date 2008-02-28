#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/support/utils'

class TestTidy < Test::Unit::TestCase
    include PuppetTest::Support::Utils
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
        file = File.join(dir, "file")
        File.open(file, "w") { |f|
            f.puts "some stuff"
        }

        tidy = Puppet.type(:tidy).create(
            :name => dir,
            :size => "1b",
            :rmdirs => true,
            :recurse => true
        )

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
        comp = mk_catalog("linktest",link)
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

        assert_equal(2 * convertors[:day], tidy.should(:age),
            "Converted 2 wrong")

        convertors.each do |name, number|
            init = name.to_s[0..0] # The first letter
            [0, 1, 5].each do |multi|
                [init, init.upcase].each do |letter|
                    age = multi.to_s + letter.to_s
                    assert_nothing_raised do
                        tidy[:age] = age
                    end

                    assert_equal(multi * convertors[name], tidy.should(:age),
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

        assert_equal(2048, tidy.should(:size),
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

                    assert_equal(total, tidy.should(:size),
                        "Converted %s wrong" % size)
                end
            end
        end
    end

    def test_agetest
        tidy = Puppet::Type.newtidy :path => tempfile(), :age => "1m"

        age = tidy.property(:age)

        # Set it to something that should be fine
        assert(age.insync?(Time.now.to_i - 5), "Tried to tidy a low age")

        # Now to something that should fail
        assert(! age.insync?(Time.now.to_i - 120), "Incorrectly skipped tidy")
    end

    def test_sizetest
        tidy = Puppet::Type.newtidy :path => tempfile(), :size => "1k"

        size = tidy.property(:size)

        # Set it to something that should be fine
        assert(size.insync?(50), "Tried to tidy a low size")

        # Now to something that should fail
        assert(! size.insync?(2048), "Incorrectly skipped tidy")
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
        tidy[:rmdirs] = true
        assert_events([:file_tidied], tidy)
        assert(! FileTest.exists?(path), "File was not removed")
    end
    
    # Make sure we can specify either attribute and get appropriate behaviour.
    # I found that the original implementation of this did not work unless both
    # size and age were specified.
    def test_one_attribute
        path = tempfile()
        File.open(path, "w") { |f| 10.times { f.puts "yayness " } }
        tidy = Puppet::Type.type(:tidy).create :path => path, :size => "1b"
        
        assert_apply(tidy)
        assert(! FileTest.exists?(path), "file did not get tidied")
        
        tidy.class.clear

        # Now try one with just an age attribute.
        time = Time.now - 10
        stat = stub 'stat', :mtime => time, :atime => time, :ftype => "file"
        File.stubs(:lstat)
        File.stubs(:lstat).with(path).returns(stat)

        File.open(path, "w") { |f| 10.times { f.puts "yayness " } }
        tidy = Puppet::Type.type(:tidy).create :path => path, :age => "5s"
        

        assert_apply(tidy)
        assert(! FileTest.exists?(path), "file did not get tidied")
    end
    
    # Testing #355.
    def test_remove_dead_links
        dir = tempfile()
        link = File.join(dir, "link")
        target = tempfile()
        Dir.mkdir(dir)
        File.symlink(target, link)
        
        tidy = Puppet::Type.newtidy :path => dir, :size => "1b", :recurse => true
        assert_apply(tidy)
        assert(! FileTest.symlink?(link), "link was not tidied")
    end

    def test_glob_matches_single
        dir = mktmpdir
        files = {
          :remove => File.join(dir, "01-foo"),
          :keep   => File.join(dir, "default")
        }
        files.each do |tag, file|
          File.open(file, "w") { |f|
              f.puts "some stuff"
          }
        end

        tidy = Puppet.type(:tidy).create(
            :name => dir,
            :size => "1b",
            :rmdirs => true,
            :recurse => true,
            :matches => "01-*"
        )
        assert_apply(tidy)

        assert(FileTest.exists?(files[:keep]), "%s was tidied" % files[:keep])
        assert(!FileTest.exists?(files[:remove]), "Tidied %s still exists" % files[:remove])
    end

    def test_glob_matches_multiple
        dir = mktmpdir
        files = {
          :remove1 => File.join(dir, "01-foo"),
          :remove2 => File.join(dir, "02-bar"),
          :keep1   => File.join(dir, "default")
        }
        files.each do |tag, file|
          File.open(file, "w") { |f|
              f.puts "some stuff"
          }
        end

        tidy = Puppet.type(:tidy).create(
            :name => dir,
            :size => "1b",
            :rmdirs => true,
            :recurse => true,
            :matches => ["01-*", "02-*"]
        )
        assert_apply(tidy)

        assert(FileTest.exists?(files[:keep1]), "%s was tidied" % files[:keep1])
        assert(!FileTest.exists?(files[:remove1]), "Tidied %s still exists" % files[:remove1])
        assert(!FileTest.exists?(files[:remove2]), "Tidied %s still exists" % files[:remove2])
    end
end

