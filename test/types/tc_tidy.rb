if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'puppettest'
require 'test/unit'

# $Id$

class TestTidy < TestPuppet
    include FileTesting
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        super
    end

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

        tidy = Puppet::Type::Tidy.new(
            :name => dir,
            :size => "1b",
            :recurse => true
        )

        comp = newcomp("tidytesting", tidy)

        trans = nil
        assert_nothing_raised {
            trans = comp.evaluate
        }
        event = nil
        assert_nothing_raised {
            event = trans.evaluate.collect { |e| e.event }
        }

        assert_equal(1, event.length, "Got no events on tidy")
        assert_equal([:file_tidied], event, "Got incorrect event on tidy")

        assert(!FileTest.exists?(file), "Tidied file still exists")
    end

    def test_tidydirs
        dir = mktmpdir
        file = File.join(dir, "tidytesting")
        File.open(file, "w") { |f|
            f.puts rand(100)
        }

        tidy = Puppet::Type::Tidy.new(
            :name => dir,
            :size => "1b",
            :age => "1s",
            :rmdirs => true,
            :recurse => true
        )

        comp = newcomp("tidytesting", tidy)

        sleep(2)
        trans = nil
        assert_nothing_raised {
            trans = comp.evaluate
        }
        event = nil
        assert_nothing_raised {
            event = trans.evaluate.collect { |e| e.event }
        }

        assert(!FileTest.exists?(file), "Tidied %s still exists" % file)
        assert(!FileTest.exists?(dir), "Tidied %s still exists" % dir)

        assert_equal(2, event.length, "Got %s events instead of %s on tidy" %
            [event.length, 2])
        assert_equal([:file_tidied, :file_tidied], event,
            "Got incorrect events on tidy")
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
