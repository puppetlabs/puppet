if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $:.unshift "../../../../language/trunk/lib"
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'cgi'
require 'test/unit'
require 'fileutils'
require 'puppettest'

class TestFileSources < Test::Unit::TestCase
	include FileTesting
    def setup
        super
        begin
            initstorage
        rescue
            system("rm -rf %s" % Puppet[:statefile])
        end
        if defined? @port
            @port += 1
        else
            @port = 8800
        end
    end

    def initstorage
        Puppet::Storage.init
        Puppet::Storage.load
    end

    def clearstorage
        Puppet::Storage.store
        Puppet::Storage.clear
    end

    def test_newchild
        path = tempfile()
        @@tmpfiles.push path

        FileUtils.mkdir_p path
        File.open(File.join(path,"childtest"), "w") { |of|
            of.puts "yayness"
        }
        file = nil
        comp = nil
        trans = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :name => path
            )
        }
        child = nil
        assert_nothing_raised {
            child = file.newchild("childtest", true)
        }
        assert(child)
        assert_raise(Puppet::DevError) {
            file.newchild(File.join(path,"childtest"), true)
        }
    end

    def test_simplelocalsource
        path = tempfile()
        @@tmpfiles.push path
        FileUtils.mkdir_p path
        frompath = File.join(path,"source")
        topath = File.join(path,"dest")
        fromfile = nil
        tofile = nil
        trans = nil

        File.open(frompath, File::WRONLY|File::CREAT|File::APPEND) { |of|
            of.puts "yayness"
        }
        assert_nothing_raised {
            tofile = Puppet.type(:file).create(
                :name => topath,
                :source => frompath
            )
        }
        comp = Puppet.type(:component).create(
            :name => "component"
        )
        comp.push tofile
        assert_nothing_raised {
            trans = comp.evaluate
        }
        assert_nothing_raised {
            trans.evaluate
        }

        assert(FileTest.exists?(topath))
        from = File.open(frompath) { |o| o.read }
        to = File.open(topath) { |o| o.read }
        assert_equal(from,to)
        @@tmpfiles.push path
    end

    def recursive_source_test(fromdir, todir)
        Puppet::Type.allclear
        initstorage
        tofile = nil
        trans = nil

        assert_nothing_raised {
            tofile = Puppet.type(:file).create(
                :name => todir,
                "recurse" => true,
                "backup" => false,
                "source" => fromdir
            )
        }
        assert_apply(tofile)

        assert(FileTest.exists?(todir), "Created dir %s does not exist" % todir)
        Puppet::Type.allclear
    end

    def run_complex_sources(networked = false)
        path = tempfile()
        @@tmpfiles.push path

        # first create the source directory
        FileUtils.mkdir_p path


        # okay, let's create a directory structure
        fromdir = File.join(path,"fromdir")
        Dir.mkdir(fromdir)
        FileUtils.cd(fromdir) {
            mkranddirsandfiles()
        }

        todir = File.join(path, "todir")
        source = fromdir
        if networked
            source = "puppet://localhost/%s%s" % [networked, fromdir]
        end
        recursive_source_test(source, todir)

        return [fromdir,todir]
    end

    def test_complex_sources_twice
        fromdir, todir = run_complex_sources
        assert_trees_equal(fromdir,todir)
        recursive_source_test(fromdir, todir)
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_deleted_destfiles
        fromdir, todir = run_complex_sources
        # then delete some files
        assert(FileTest.exists?(todir))
        missing_files = delete_random_files(todir)

        # and run
        recursive_source_test(fromdir, todir)

        missing_files.each { |file|
            assert(FileTest.exists?(file), "Deleted file %s is still missing" % file)
        }

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_readonly_destfiles
        fromdir, todir = run_complex_sources
        assert(FileTest.exists?(todir))
        readonly_random_files(todir)
        recursive_source_test(fromdir, todir)

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_modified_dest_files
        fromdir, todir = run_complex_sources

        assert(FileTest.exists?(todir))
        # then modify some files
        modify_random_files(todir)

        recursive_source_test(fromdir, todir)

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_added_destfiles
        fromdir, todir = run_complex_sources
        assert(FileTest.exists?(todir))
        # and finally, add some new files
        add_random_files(todir)

        recursive_source_test(fromdir, todir)

        fromtree = file_list(fromdir)
        totree = file_list(todir)

        assert(fromtree != totree)

        # then remove our new files
        FileUtils.cd(todir) {
            %x{find . 2>/dev/null}.chomp.split(/\n/).each { |file|
                if file =~ /file[0-9]+/
                    File.unlink(file)
                end
            }
        }

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_RecursionWithAddedFiles
        basedir = tempfile()
        Dir.mkdir(basedir)
        @@tmpfiles << basedir
        file1 = File.join(basedir, "file1")
        file2 = File.join(basedir, "file2")
        subdir1 = File.join(basedir, "subdir1")
        file3 = File.join(subdir1, "file")
        File.open(file1, "w") { |f| 3.times { f.print rand(100) } }
        rootobj = nil
        assert_nothing_raised {
            rootobj = Puppet.type(:file).create(
                :name => basedir,
                :recurse => true,
                :check => %w{type owner}
            )

            rootobj.evaluate
        }

        klass = Puppet.type(:file)
        assert(klass[basedir])
        assert(klass[file1])
        assert_nil(klass[file2])

        File.open(file2, "w") { |f| 3.times { f.print rand(100) } }

        assert_nothing_raised {
            rootobj.evaluate
        }
        assert(klass[file2])

        Dir.mkdir(subdir1)
        File.open(file3, "w") { |f| 3.times { f.print rand(100) } }

        assert_nothing_raised {
            rootobj.evaluate
        }
        assert(klass[file3])
    end

    def mkfileserverconf(mounts)
        file = tempfile()
        File.open(file, "w") { |f|
            mounts.each { |path, name|
                f.puts "[#{name}]\n\tpath #{path}\n\tallow *\n"
            }
        }

        @@tmpfiles << file
        return file
    end

    # test raw xmlrpc calls
    # this test is disabled because it requires way too much setup to get
    # the certificates correct
    def disabled_test_SimpleNetworkSources
        server = nil
        basedir = tempfile()
        @@tmpfiles << basedir

        mounts = {
            "/" => "root"
        }

        fileserverconf = mkfileserverconf(mounts)

        if File.exists?(basedir)
            system("rm -rf %s" % basedir)
        end
        Dir.mkdir(basedir)

        Puppet[:confdir] = basedir
        Puppet[:vardir] = basedir
        Puppet[:autosign] = true

        tmpname = "yaytesting"
        tmpfile = File.join(basedir, tmpname)
        File.open(tmpfile, "w") { |f| f.print rand(100) }

        port = 8765
        serverpid = nil
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :FileServer => {
                        :Config => fileserverconf
                    }
                }
            )

        }
        serverpid = fork {
            assert_nothing_raised() {
                #trap(:INT) { server.shutdown; Kernel.exit! }
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << serverpid

        client = nil
        assert_nothing_raised() {
            client = XMLRPC::Client.new("localhost", "/RPC2", port, nil, nil,
                nil, nil, true, 3)
        }
        retval = nil

        sleep(1)

        list = nil
        rpath = "/root%s" % tmpfile
        assert_nothing_raised {
            list = client.call("fileserver.list", rpath, false, false)
        }

        assert_equal("/\tfile", list)

        assert_nothing_raised {
            list = client.call("fileserver.describe", rpath)
        }

        assert_match(/^\d+\tfile\t\d+\t\d+\t.+$/, list)

        assert_nothing_raised {
            list = client.call("fileserver.retrieve", rpath)
        }

        contents = File.read(tmpfile)
        assert_equal(contents, CGI.unescape(list))

        assert_nothing_raised {
            system("kill -INT %s" % serverpid)
        }
    end

    def test_NetworkSources
        server = nil
        basedir = tempfile()
        @@tmpfiles << basedir
        Dir.mkdir(basedir)

        mounts = {
            "/" => "root"
        }

        fileserverconf = mkfileserverconf(mounts)

        Puppet[:confdir] = basedir
        Puppet[:vardir] = basedir
        Puppet[:autosign] = true

        Puppet[:masterport] = 8762

        serverpid = nil
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :FileServer => {
                        :Config => fileserverconf
                    }
                }
            )

        }
        serverpid = fork {
            assert_nothing_raised() {
                #trap(:INT) { server.shutdown; Kernel.exit! }
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << serverpid

        sleep(1)

        fromdir, todir = run_complex_sources("root")
        assert_trees_equal(fromdir,todir)
        recursive_source_test(fromdir, todir)
        assert_trees_equal(fromdir,todir)

        assert_nothing_raised {
            system("kill -INT %s" % serverpid)
        }
    end

    def test_networkSourcesWithoutService
        server = nil

        Puppet[:autosign] = true
        Puppet[:masterport] = 8765

        serverpid = nil
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                }
            )

        }
        serverpid = fork {
            assert_nothing_raised() {
                #trap(:INT) { server.shutdown; Kernel.exit! }
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << serverpid

        sleep(1)

        name = File.join(tmpdir(), "nosourcefile")
        file = Puppet.type(:file).create(
            :source => "puppet://localhost/dist/file",
            :name => name
        )

        assert_nothing_raised {
            file.retrieve
        }

        comp = newcomp("nosource", file)

        assert_nothing_raised {
            comp.evaluate
        }

        assert(!FileTest.exists?(name), "File with no source exists anyway")
    end

    def test_unmountedNetworkSources
        server = nil
        mounts = {
            "/" => "root",
            "/noexistokay" => "noexist"
        }

        fileserverconf = mkfileserverconf(mounts)

        Puppet[:autosign] = true
        Puppet[:masterport] = @port

        serverpid = nil
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => @port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :FileServer => {
                        :Config => fileserverconf
                    }
                }
            )

        }

        serverpid = fork {
            assert_nothing_raised() {
                #trap(:INT) { server.shutdown; Kernel.exit! }
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << serverpid

        sleep(1)

        name = File.join(tmpdir(), "nosourcefile")
        file = Puppet.type(:file).create(
            :source => "puppet://localhost/noexist/file",
            :name => name
        )

        assert_nothing_raised {
            file.retrieve
        }

        comp = newcomp("nosource", file)

        assert_nothing_raised {
            comp.evaluate
        }

        assert(!FileTest.exists?(name), "File with no source exists anyway")
    end

    def test_alwayschecksum
        from = tempfile()
        to = tempfile()

        File.open(from, "w") { |f| f.puts "yayness" }
        File.open(to, "w") { |f| f.puts "yayness" }

        file = nil

        # Now the files should be exactly the same, so we should not see attempts
        # at copying
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :path => to,
                :source => from
            )
        }

        file.retrieve

        assert(file.is(:checksum), "File does not have a checksum state")

        assert_equal(0, file.evaluate.length, "File produced changes")

    end

    def test_sourcepaths
        files = []
        3.times { 
            files << tempfile()
        }

        to = tempfile()

        File.open(files[-1], "w") { |f| f.puts "yee-haw" }

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :name => to,
                :source => files
            )
        }

        comp = newcomp(file)
        assert_events([:file_created], comp)

        assert(File.exists?(to), "File does not exist")

        txt = nil
        File.open(to) { |f| txt = f.read.chomp }

        assert_equal("yee-haw", txt, "Contents do not match")
    end
end

# $Id$
