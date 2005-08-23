if __FILE__ == $0
    if Dir.getwd =~ /test\/server$/
        Dir.chdir("..")
    end

    $:.unshift '../lib'
    $:.unshift '../../../library/trunk/lib/'
    $:.unshift '../../../library/trunk/test/'
    $puppetbase = ".."

end

require 'puppet'
require 'puppet/fileserver'
require 'test/unit'
require 'puppettest.rb'

class TestFileServer < TestPuppet
    def setup
        if __FILE__ == $0
            Puppet[:loglevel] = :debug
        end

        super
    end

    def mkrandomdirs(dir, depth, width)
        assert_nothing_raised {
            Dir.mkdir(dir)
        }

    end

    def test_namefailures
        server = nil
        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        assert_raise(Puppet::FileServerError) {
            server.mount("/tmp", "invalid+name")
        }

        assert_raise(Puppet::FileServerError) {
            server.mount("/tmp", "invalid-name")
        }

        assert_raise(Puppet::FileServerError) {
            server.mount("/tmp", "invalid name")
        }

        assert_raise(Puppet::FileServerError) {
            server.mount("/tmp", "")
        }
    end

    def test_listroot
        server = nil
        testdir = "/tmp/remotefilecopying"
        tmpfile = File.join(testdir, "tmpfile")
        assert_nothing_raised {
            Dir.mkdir(testdir)
            File.open(tmpfile, "w") { |f|
                3.times { f.puts rand(100) }
            }
            @@tmpfiles << testdir
        }

        file = nil
        checks = Puppet::FileServer::CHECKPARAMS

        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        list = nil
        assert_nothing_raised {
            list = server.list("/test/", true)
        }

        assert(list =~ /tmpfile/)

        assert_nothing_raised {
            list = server.list("/test", true)
        }
        assert(list =~ /tmpfile/)

    end

    def test_getfilelist
        server = nil
        testdir = "/tmp/remotefilecopying"
        #subdir = "testingyo"
        #subpath = File.join(testdir, "testingyo")
        #dir = File.join(testdir, subdir)
        tmpfile = File.join(testdir, "tmpfile")
        assert_nothing_raised {
            Dir.mkdir(testdir)
            #Dir.mkdir(subpath)
            File.open(tmpfile, "w") { |f|
                3.times { f.puts rand(100) }
            }
            @@tmpfiles << testdir
        }

        file = nil

        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        list = nil
        sfile = "/test/tmpfile"
        assert_nothing_raised {
            list = server.list(sfile, true)
        }

        assert_nothing_raised {
            file = Puppet::Type::PFile[tmpfile]
        }

        output = "/\tfile"

        assert_equal(output, list)
        assert(list !~ /\t\t/)

        list.split("\n").each { |line|
            assert(line !~ %r{remotefile})
        }
        contents = File.read(tmpfile)

        ret = nil
        assert_nothing_raised {
            ret = server.retrieve(sfile)
        }

        assert_equal(contents, ret)
    end

    def test_seenewfiles
        server = nil
        testdir = "/tmp/remotefilecopying"
        oldfile = File.join(testdir, "oldfile")
        newfile = File.join(testdir, "newfile")
        assert_nothing_raised {
            Dir.mkdir(testdir)
            File.open(oldfile, "w") { |f|
                3.times { f.puts rand(100) }
            }
            @@tmpfiles << testdir
        }

        file = nil
        checks = Puppet::FileServer::CHECKPARAMS

        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        list = nil
        sfile = "/test/"
        assert_nothing_raised {
            list = server.list(sfile, true)
        }

        File.open(newfile, "w") { |f|
            3.times { f.puts rand(100) }
        }

        newlist = nil
        assert_nothing_raised {
            newlist = server.list(sfile, true)
        }

        assert(list != newlist)

        assert(newlist =~ /newfile/)
    end

    def test_mountroot
        server = nil
        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        assert_nothing_raised {
            server.mount("/", "root")
        }

        testdir = "/tmp/remotefilecopying"
        oldfile = File.join(testdir, "oldfile")
        assert_nothing_raised {
            Dir.mkdir(testdir)
            File.open(oldfile, "w") { |f|
                3.times { f.puts rand(100) }
            }
            @@tmpfiles << testdir
        }

        list = nil
        assert_nothing_raised {
            list = server.list("/root/" + testdir, true)
        }

        assert(list =~ /oldfile/)
    end

    def test_recursionlevels
        server = nil
        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        basedir = "/tmp/remotefilecopying"
        testdir = "%s/with/some/sub/directories/for/the/purposes/of/testing" % basedir
        oldfile = File.join(testdir, "oldfile")
        assert_nothing_raised {
            system("mkdir -p %s" % testdir)
            File.open(oldfile, "w") { |f|
                3.times { f.puts rand(100) }
            }
            @@tmpfiles << basedir
        }

        assert_nothing_raised {
            server.mount(basedir, "test")
        }

        list = nil
        assert_nothing_raised {
            list = server.list("/test/with", false)
        }

        assert(list !~ /\n/)

        [0, 1, 2].each { |num|
            assert_nothing_raised {
                list = server.list("/test/with", num)
            }

            count = 0
            #p list
            while list =~ /\n/
                list.sub!(/\n/, '')
                count += 1
            end
            assert_equal(num, count)
        }
    end

    def test_listedpath
        server = nil
        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        basedir = "/tmp/remotefilecopying"
        testdir = "%s/with/some/sub/directories/for/testing" % basedir
        oldfile = File.join(testdir, "oldfile")
        assert_nothing_raised {
            system("mkdir -p %s" % testdir)
            File.open(oldfile, "w") { |f|
                3.times { f.puts rand(100) }
            }
            @@tmpfiles << basedir
        }

        assert_nothing_raised {
            server.mount(basedir, "localhost")
        }

        list = nil
        assert_nothing_raised {
            list = server.list("/localhost/with", false)
        }

        assert(list !~ /with/)

        assert_nothing_raised {
            list = server.list("/localhost/with/some/sub", true)
        }

        assert(list !~ /sub/)
    end

    def test_widelists
        server = nil
        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        basedir = "/tmp/remotefilecopying"
        dirs = %w{a set of directories}
        assert_nothing_raised {
            Dir.mkdir(basedir)
            dirs.each { |dir|
                Dir.mkdir(File.join(basedir, dir))
            }
            @@tmpfiles << basedir
        }

        assert_nothing_raised {
            server.mount(basedir, "localhost")
        }

        list = nil
        assert_nothing_raised {
            list = server.list("/localhost/", 1).split("\n")
        }

        assert_equal(dirs.length + 1, list.length)
    end

    def test_describe
        server = nil
        testdir = "/tmp/remotefilecopying"
        assert_nothing_raised {
            Dir.mkdir(testdir)
            @@tmpfiles << testdir
            %w{a b c d e}.each { |l|
                name = File.join(testdir, "file%s" % name)
                File.open(name, "w") { |f|
                    f.puts rand(100)
                }
            }
        }

        file = nil
        checks = Puppet::FileServer::CHECKPARAMS

        assert_nothing_raised {
            server = Puppet::FileServer.new(
                :Local => true
            )
        }

        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        list = nil
        sfile = "/test/"
        assert_nothing_raised {
            list = server.list(sfile, true)
        }

        assert_nothing_raised {
            list.split("\n").each { |line|
                file, type = line.split("\t")

                desc = server.describe(sfile + file)
            }
        }
    end
end

# $Id$

