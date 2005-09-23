if __FILE__ == $0
    if Dir.getwd =~ /test\/server$/
        Dir.chdir("..")
    end

    $:.unshift '../lib'
    $puppetbase = ".."

end

require 'puppet'
require 'puppet/server/fileserver'
require 'test/unit'
require 'puppettest.rb'

class TestFileServer < TestPuppet
    # make a simple file source
    def mktestdir
        testdir = File.join(tmpdir(), "remotefilecopytesting")
        @@tmpfiles << testdir

        # create a tmpfile
        pattern = "tmpfile"
        tmpfile = File.join(testdir, pattern)
        assert_nothing_raised {
            Dir.mkdir(testdir)
            File.open(tmpfile, "w") { |f|
                3.times { f.puts rand(100) }
            }
        }

        return [testdir, %r{#{pattern}}, tmpfile]
    end

    # make a bunch of random test files
    def mktestfiles(testdir)
        @@tmpfiles << testdir
        assert_nothing_raised {
            Dir.mkdir(testdir)
            @@tmpfiles << testdir
            files = %w{a b c d e}.collect { |l|
                name = File.join(testdir, "file%s" % l)
                File.open(name, "w") { |f|
                    f.puts rand(100)
                }
                
                name
            }

            return files
        }
    end

    def assert_describe(base, file, server)
        file = File.basename(file)
        assert_nothing_raised {
            desc = server.describe(base + file)
            assert(desc, "Got no description for %s" % file)
            assert(desc != "", "Got no description for %s" % file)
            assert_match(/^\d+/, desc, "Got invalid description %s" % desc)
        }
    end

    # test for invalid names
    def test_namefailures
        server = nil
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }

        assert_raise(Puppet::Server::FileServerError) {
            server.mount("/tmp", "invalid+name")
        }

        assert_raise(Puppet::Server::FileServerError) {
            server.mount("/tmp", "invalid-name")
        }

        assert_raise(Puppet::Server::FileServerError) {
            server.mount("/tmp", "invalid name")
        }

        assert_raise(Puppet::Server::FileServerError) {
            server.mount("/tmp", "")
        }
    end

    # verify that listing the root behaves as expected
    def test_listroot
        server = nil
        testdir, pattern, tmpfile = mktestdir()

        file = nil
        checks = Puppet::Server::FileServer::CHECKPARAMS

        # and make our fileserver
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }

        # mount the testdir
        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        # and verify different iterations of 'root' return the same value
        list = nil
        assert_nothing_raised {
            list = server.list("/test/", true, false)
        }

        assert(list =~ pattern)

        assert_nothing_raised {
            list = server.list("/test", true, false)
        }
        assert(list =~ pattern)

    end

    # test listing individual files
    def test_getfilelist
        server = nil
        testdir, pattern, tmpfile = mktestdir()

        file = nil

        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }

        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        # get our listing
        list = nil
        sfile = "/test/tmpfile"
        assert_nothing_raised {
            list = server.list(sfile, true, false)
        }

        assert_nothing_raised {
            file = Puppet::Type::PFile[tmpfile]
        }

        output = "/\tfile"

        # verify it got listed as a file
        assert_equal(output, list)

        # verify we got all fields
        assert(list !~ /\t\t/)

        # verify that we didn't get the directory itself
        list.split("\n").each { |line|
            assert(line !~ %r{remotefile})
        }

        # and then verify that the contents match
        contents = File.read(tmpfile)

        ret = nil
        assert_nothing_raised {
            ret = server.retrieve(sfile)
        }

        assert_equal(contents, ret)
    end

    # check that the fileserver is seeing newly created files
    def test_seenewfiles
        server = nil
        testdir, pattern, tmpfile = mktestdir()


        newfile = File.join(testdir, "newfile")

        # go through the whole schtick again...
        file = nil
        checks = Puppet::Server::FileServer::CHECKPARAMS

        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }

        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        list = nil
        sfile = "/test/"
        assert_nothing_raised {
            list = server.list(sfile, true, false)
        }

        # create the new file
        File.open(newfile, "w") { |f|
            3.times { f.puts rand(100) }
        }

        newlist = nil
        assert_nothing_raised {
            newlist = server.list(sfile, true, false)
        }

        # verify the list has changed
        assert(list != newlist)

        # and verify that we are specifically seeing the new file
        assert(newlist =~ /newfile/)
    end

    # verify we can mount /, which is what local file servers will
    # normally do
    def test_mountroot
        server = nil
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }

        assert_nothing_raised {
            server.mount("/", "root")
        }

        testdir, pattern, tmpfile = mktestdir()

        list = nil
        assert_nothing_raised {
            list = server.list("/root/" + testdir, true, false)
        }

        assert(list =~ pattern)
    end

    # verify that we're correctly recursing the right number of levels
    def test_recursionlevels
        server = nil
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }

        # make our deep recursion
        basedir = File.join(tmpdir(), "recurseremotetesting")
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

        # get our list
        list = nil
        assert_nothing_raised {
            list = server.list("/test/with", false, false)
        }

        # make sure we only got one line, since we're not recursing
        assert(list !~ /\n/)

        # for each level of recursion, make sure we get the right list
        [0, 1, 2].each { |num|
            assert_nothing_raised {
                list = server.list("/test/with", num, false)
            }

            count = 0
            while list =~ /\n/
                list.sub!(/\n/, '')
                count += 1
            end
            assert_equal(num, count)
        }
    end

    # verify that we're not seeing the dir we ask for; i.e., that our
    # list is relative to that dir, not it's parent dir
    def test_listedpath
        server = nil
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }


        # create a deep dir
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

        # mounty mounty
        assert_nothing_raised {
            server.mount(basedir, "localhost")
        }

        list = nil
        # and then check a few dirs
        assert_nothing_raised {
            list = server.list("/localhost/with", false, false)
        }

        assert(list !~ /with/)

        assert_nothing_raised {
            list = server.list("/localhost/with/some/sub", true, false)
        }

        assert(list !~ /sub/)
    end

    # test many dirs, not necessarily very deep
    def test_widelists
        server = nil
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
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
            list = server.list("/localhost/", 1, false)
        }
        assert_instance_of(String, list, "Server returned %s instead of string")
        list = list.split("\n")

        assert_equal(dirs.length + 1, list.length)
    end

    # verify that 'describe' works as advertised
    def test_describe
        server = nil
        testdir = "/tmp/remotefilecopying"
        files = mktestfiles(testdir)

        file = nil
        checks = Puppet::Server::FileServer::CHECKPARAMS

        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }

        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        # get our list
        list = nil
        sfile = "/test/"
        assert_nothing_raised {
            list = server.list(sfile, true, false)
        }

        # and describe each file in the list
        assert_nothing_raised {
            list.split("\n").each { |line|
                file, type = line.split("\t")

                desc = server.describe(sfile + file)
            }
        }

        # and then make sure we can describe everything that we know is there
        files.each { |file|
            assert_describe(sfile, file, server)
        }

        # And then describe some files that we know aren't there
        retval = nil
        assert_nothing_raised("Describing non-existent files raised an error") {
            retval = server.describe(sfile + "noexisties")
        }

        assert_equal("", retval, "Description of non-existent files returned a value")

        # Now try to describe some sources that don't even exist
        retval = nil
        assert_raise(Puppet::Server::FileServerError,
            "Describing non-existent mount did not raise an error") {
            retval = server.describe("/notmounted/" + "noexisties")
        }

        assert_nil(retval, "Description of non-existent mounts returned a value")
    end

    # test that our config file is parsing and working as planned
    def test_configfile
        server = nil
        basedir = File.join(tmpdir, "fileserverconfigfiletesting")
        @@tmpfiles << basedir

        # make some dirs for mounting
        Dir.mkdir(basedir)
        mounts = {}
        %w{thing thus these those}.each { |dir|
            path = File.join(basedir, dir)
            mounts[dir] = mktestfiles(path)

        }

        # create an example file with each of them
        conffile = tempfile
        @@tmpfiles << conffile

        File.open(conffile, "w") { |f|
            f.print "# a test config file
 
[thing]
    path #{basedir}/thing
    allow 192.168.0.*

[thus]
    path #{basedir}/thus
    allow *.madstop.com, *.kanies.com
    deny *.sub.madstop.com

[these]
    path #{basedir}/these

[those]
    path #{basedir}/those

"
        }
        

        # create a server with the file
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => conffile
            )
        }

        list = nil
        # run through once with no host/ip info, to verify everything is working
        mounts.each { |mount, files|
            mount = "/#{mount}/"
            assert_nothing_raised {
                list = server.list(mount, true, false)
            }

            assert_nothing_raised {
                list.split("\n").each { |line|
                    file, type = line.split("\t")

                    desc = server.describe(mount + file)
                }
            }

            files.each { |f|
                assert_describe(mount, f, server)
            }
        }

        # now let's check that things are being correctly forbidden
        # this is just a map of names and expected results
        {
            "thing" => {
                :deny => [
                    ["hostname.com", "192.168.1.0"],
                    ["hostname.com", "192.158.0.0"]
                ],
                :allow => [
                    ["hostname.com", "192.168.0.0"],
                    ["hostname.com", "192.168.0.245"],
                ]
            },
            "thus" => {
                :deny => [
                    ["hostname.com", "192.168.1.0"],
                    ["name.sub.madstop.com", "192.158.0.0"]
                ],
                :allow => [
                    ["luke.kanies.com", "192.168.0.0"],
                    ["luke.madstop.com", "192.168.0.245"],
                ]
            }
        }.each { |mount, hash|
            mount = "/#{mount}/"

            # run through the map
            hash.each { |type, ary|
                ary.each { |sub|
                    host, ip = sub

                    case type
                    when :deny:
                        assert_raise(Puppet::Server::AuthorizationError,
                            "Host %s, ip %s, allowed %s" %
                            [host, ip, mount]) {
                                list = server.list(mount, true, false, host, ip)
                        }
                    when :allow:
                        assert_nothing_raised("Host %s, ip %s, denied %s" %
                            [host, ip, mount]) {
                                list = server.list(mount, true, false, host, ip)
                        }
                    end
                }
            }
        }

    end

    # Test that we smoothly handle invalid config files
    def test_configfailures
        # create an example file with each of them
        conffile = tempfile()

        invalidmounts = {
            "noexist" => "[noexist]
    path /this/path/does/not/exist
    allow 192.168.0.*
"
}

        invalidconfigs = [
"[not valid]
    path /this/path/does/not/exist
    allow 192.168.0.*
",
"[valid]
    invalidstatement
    path /etc
    allow 192.168.0.*
",
"[valid]
    allow 192.168.0.*
"
]

        invalidmounts.each { |mount, text|
            File.open(conffile, "w") { |f|
                f.print text
            }
            

            # create a server with the file
            server = nil
            assert_nothing_raised {
                server = Puppet::Server::FileServer.new(
                    :Local => true,
                    :Config => conffile
                )
            }

            assert_raise(Puppet::Server::FileServerError,
                "Invalid mount was mounted") {
                    server.list(mount)
            }
        }

        invalidconfigs.each_with_index { |text, i|
            File.open(conffile, "w") { |f|
                f.print text
            }
            

            # create a server with the file
            server = nil
            assert_raise(Puppet::Server::FileServerError,
                "Invalid config %s did not raise error" % i) {
                server = Puppet::Server::FileServer.new(
                    :Local => true,
                    :Config => conffile
                )
            }
        }
    end

    # verify we reread the config file when it changes
    def test_filereread
        server = nil

        dir = testdir()

        files = mktestfiles(dir)

        conffile = tempfile()

        File.open(conffile, "w") { |f|
            f.print "# a test config file
 
[thing]
    path #{dir}
    allow test1.domain.com
"
        }
        

        # start our server with a fast timeout
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :ConfigTimeout => 0.5,
                :Config => conffile
            )
        }

        list = nil
        assert_nothing_raised {
            list = server.list("/thing/", false, false,
                "test1.domain.com", "127.0.0.1")
        }
        assert(list != "", "List returned nothing in rereard test")

        assert_raise(Puppet::Server::AuthorizationError, "List allowed invalid host") {
            list = server.list("/thing/", false, false,
                "test2.domain.com", "127.0.0.1")
        }

        sleep 1
        File.open(conffile, "w") { |f|
            f.print "# a test config file
 
[thing]
    path #{dir}
    allow test2.domain.com
"
        }
        
        assert_raise(Puppet::Server::AuthorizationError, "List allowed invalid host") {
            list = server.list("/thing/", false, false,
                "test1.domain.com", "127.0.0.1")
        }

        assert_nothing_raised {
            list = server.list("/thing/", false, false,
                "test2.domain.com", "127.0.0.1")
        }

        assert(list != "", "List returned nothing in rereard test")

        list = nil
    end

end

# $Id$

