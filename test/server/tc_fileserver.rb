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
    def setup
        if __FILE__ == $0
            Puppet[:loglevel] = :debug
        end

        @@tmppids = []
        super
    end

    def teardown
        super
        @@tmppids.each { |pid|
            system("kill -INT %s" % pid)
        }
    end

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
        assert_nothing_raised {
            list = server.list("/test/", true, false)
        }

        assert(list =~ /tmpfile/)

        assert_nothing_raised {
            list = server.list("/test", true, false)
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
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
            )
        }

        assert_nothing_raised {
            server.mount(testdir, "test")
        }

        list = nil
        sfile = "/test/tmpfile"
        assert_nothing_raised {
            list = server.list(sfile, true, false)
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

        File.open(newfile, "w") { |f|
            3.times { f.puts rand(100) }
        }

        newlist = nil
        assert_nothing_raised {
            newlist = server.list(sfile, true, false)
        }

        assert(list != newlist)

        assert(newlist =~ /newfile/)
    end

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
            list = server.list("/root/" + testdir, true, false)
        }

        assert(list =~ /oldfile/)
    end

    def test_recursionlevels
        server = nil
        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
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
            list = server.list("/test/with", false, false)
        }

        assert(list !~ /\n/)

        [0, 1, 2].each { |num|
            assert_nothing_raised {
                list = server.list("/test/with", num, false)
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
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :Config => false
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
            list = server.list("/localhost/with", false, false)
        }

        assert(list !~ /with/)

        assert_nothing_raised {
            list = server.list("/localhost/with/some/sub", true, false)
        }

        assert(list !~ /sub/)
    end

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

        list = nil
        sfile = "/test/"
        assert_nothing_raised {
            list = server.list(sfile, true, false)
        }

        assert_nothing_raised {
            list.split("\n").each { |line|
                file, type = line.split("\t")

                desc = server.describe(sfile + file)
            }
        }

        files.each { |file|
            file = File.basename(file)
            assert_nothing_raised {
                desc = server.describe(sfile + file)
                assert(desc, "Got no description for %s" % file)
                assert(desc != "", "Got no description for %s" % file)
                assert_match(/^\d+/, desc, "Got invalid description %s" % desc)
            }
        }
    end

    def test_configfile
        server = nil
        basedir = "/tmp/configfiletesting"

        conftext = "# a test config file\n \n"

        @@tmpfiles << basedir

        Dir.mkdir(basedir)
        mounts = {}
        %w{thing thus these those}.each { |dir|
            path = File.join(basedir, dir)
            conftext << "[#{dir}]
    path #{path}
"
            mounts[dir] = mktestfiles(path)

        }

        conffile = "/tmp/fileservertestingfile"
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
                file = File.basename(f)
                desc = server.describe(mount + file)
                assert(desc, "Got no description for %s" % f)
                assert(desc != "", "Got no description for %s" % f)
                assert_match(/^\d+/, desc, "Got invalid description %s" % f)
            }
        }

        # now let's check that things are being correctly forbidden
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

    def test_filereread
        server = nil
        testdir = "/tmp/filerereadtesting"

        @@tmpfiles << testdir

        #Dir.mkdir(testdir)
        files = mktestfiles(testdir)

        conffile = "/tmp/fileservertestingfile"
        @@tmpfiles << conffile

        File.open(conffile, "w") { |f|
            f.print "# a test config file
 
[thing]
    path #{testdir}
    allow test1.domain.com
"
        }
        

        assert_nothing_raised {
            server = Puppet::Server::FileServer.new(
                :Local => true,
                :ConfigTimeout => 0.5,
                :Config => conffile
            )
        }

        list = nil
        assert_nothing_raised {
            list = server.list("/thing/", false, false, "test1.domain.com", "127.0.0.1")
        }
        assert(list != "", "List returned nothing in rereard test")

        assert_raise(Puppet::Server::AuthorizationError, "List allowed invalid host") {
            list = server.list("/thing/", false, false, "test2.domain.com", "127.0.0.1")
        }

        sleep 1
        File.open(conffile, "w") { |f|
            f.print "# a test config file
 
[thing]
    path #{testdir}
    allow test2.domain.com
"
        }
        
        assert_raise(Puppet::Server::AuthorizationError, "List allowed invalid host") {
            list = server.list("/thing/", false, false, "test1.domain.com", "127.0.0.1")
        }

        assert_nothing_raised {
            list = server.list("/thing/", false, false, "test2.domain.com", "127.0.0.1")
        }

        assert(list != "", "List returned nothing in rereard test")

        list = nil
    end

end

# $Id$

