if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'
require 'fileutils'

# $Id$

class TestFile < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        @@tmpfiles = []
        @file = nil
        @path = File.join($puppetbase,"examples/root/etc/configfile")
        Puppet[:loglevel] = :debug if __FILE__ == $0
        Puppet[:statefile] = "/var/tmp/puppetstate"
        assert_nothing_raised() {
            @file = Puppet::Type::PFile.new(
                :name => @path
            )
        }
    end

    def teardown
        Puppet::Type.allclear
        @@tmpfiles.each { |file|
            if FileTest.exists?(file)
                system("chmod -R 755 %s" % file)
                system("rm -rf %s" % file)
            end
        }
        system("rm -f %s" % Puppet[:statefile])
    end

    def initstorage
        Puppet::Storage.init
        Puppet::Storage.load
    end

    def clearstorage
        Puppet::Storage.store
        Puppet::Storage.clear
        initstorage()
    end

    def test_owner
        [Process.uid,%x{whoami}.chomp].each { |user|
            assert_nothing_raised() {
                @file[:owner] = user
            }
            assert_nothing_raised() {
                @file.evaluate
            }
            assert_nothing_raised() {
                @file.sync
            }
            assert_nothing_raised() {
                @file.evaluate
            }
            assert(@file.insync?())
        }
        assert_nothing_raised() {
            @file[:owner] = "root"
        }
        assert_nothing_raised() {
            @file.evaluate
        }
        # we might already be in sync
        assert(!@file.insync?())
        assert_nothing_raised() {
            @file.delete(:owner)
        }
    end

    def test_group
        [%x{groups}.chomp.split(/ /), Process.groups].flatten.each { |group|
            assert_nothing_raised() {
                @file[:group] = group
            }
            assert_nothing_raised() {
                @file.evaluate
            }
            assert_nothing_raised() {
                @file.sync
            }
            assert_nothing_raised() {
                @file.evaluate
            }
            assert(@file.insync?())
            assert_nothing_raised() {
                @file.delete(:group)
            }
        }
    end

    def test_create
        %w{a b c d}.collect { |name| "/tmp/createst%s" % name }.each { |path|
            file =nil
            assert_nothing_raised() {
                file = Puppet::Type::PFile.new(
                    :name => path,
                    :create => true
                )
            }
            assert_nothing_raised() {
                file.evaluate
            }
            assert_nothing_raised() {
                file.sync
            }
            assert_nothing_raised() {
                file.evaluate
            }
            assert(file.insync?())
            assert(FileTest.file?(path))
            @@tmpfiles.push path
        }
    end

    def test_create_dir
        %w{a b c d}.collect { |name| "/tmp/createst%s" % name }.each { |path|
            file = nil
            assert_nothing_raised() {
                file = Puppet::Type::PFile.new(
                    :name => path,
                    :create => "directory"
                )
            }
            assert_nothing_raised() {
                file.evaluate
            }
            assert_nothing_raised() {
                file.sync
            }
            assert_nothing_raised() {
                file.evaluate
            }
            assert(file.insync?())
            assert(FileTest.directory?(path))
            @@tmpfiles.push path
        }
    end

    def test_modes
        [0644,0755,0777,0641].each { |mode|
            assert_nothing_raised() {
                @file[:mode] = mode
            }
            assert_nothing_raised() {
                @file.evaluate
            }
            assert_nothing_raised() {
                @file.sync
            }
            assert_nothing_raised() {
                @file.evaluate
            }
            assert(@file.insync?())
            assert_nothing_raised() {
                @file.delete(:mode)
            }
        }
    end

    # just test normal links
    def test_normal_links
        link = "/tmp/puppetlink"
        assert_nothing_raised() {
            @file[:link] = link
        }
        # assert we got a fully qualified link
        assert(@file.state(:link).should =~ /^\//)

        # assert we aren't linking to ourselves
        assert(File.expand_path(@file.state(:link).link) !=
            File.expand_path(@file[:path]))

        # assert the should value does point to us
        assert_equal(File.expand_path(@file.state(:link).should),
            File.expand_path(@file[:path]))

        assert_nothing_raised() {
            @file.evaluate
        }
        assert_nothing_raised() {
            @file.sync
        }
        assert_nothing_raised() {
            @file.evaluate
        }
        assert(@file.insync?())
        assert_nothing_raised() {
            @file.delete(:link)
        }
        @@tmpfiles.push link
    end

    def test_checksums
        types = %w{md5 md5lite timestamp ctime}
        exists = "/tmp/sumtest-exists"
        nonexists = "/tmp/sumtest-nonexists"

        # try it both with files that exist and ones that don't
        files = [exists, nonexists]
        initstorage
        File.open(exists,"w") { |of|
            10.times { 
                of.puts rand(100)
            }
        }
        types.each { |type|
            files.each { |path|
                if Puppet[:debug]
                    Puppet.info "Testing %s on %s" % [type,path]
                end
                file = nil
                events = nil
                # okay, we now know that we have a file...
                assert_nothing_raised() {
                    file = Puppet::Type::PFile.new(
                        :name => path,
                        :create => true,
                        :checksum => type
                    )
                }
                assert_nothing_raised() {
                    file.evaluate
                }
                assert_nothing_raised() {
                    events = file.sync
                }
                # we don't want to kick off an event the first time we
                # come across a file
                assert(
                    ! events.include?(:file_modified)
                )
                assert_nothing_raised() {
                    File.open(path,"w") { |of|
                        10.times { 
                            of.puts rand(100)
                        }
                    }
                    #system("cat %s" % path)
                }
                Puppet::Type::PFile.clear
                # now recreate the file
                assert_nothing_raised() {
                    file = Puppet::Type::PFile.new(
                        :name => path,
                        :checksum => type
                    )
                }
                assert_nothing_raised() {
                    file.evaluate
                }
                assert_nothing_raised() {
                    events = file.sync
                }
                # verify that we're actually getting notified when a file changes
                assert(
                    events.include?(:file_modified)
                )
                assert_nothing_raised() {
                    Puppet::Type::PFile.clear
                }
                @@tmpfiles.push path
            }
        }
        # clean up so i don't screw up other tests
        Puppet::Storage.clear
    end

    def cyclefile(path)
        # i had problems with using :name instead of :path
        [:name,:path].each { |param|
            file = nil
            changes = nil
            comp = nil
            trans = nil

            initstorage
            assert_nothing_raised {
                file = Puppet::Type::PFile.new(
                    param => path,
                    :recurse => true,
                    :checksum => "md5"
                )
            }
            comp = Puppet::Component.new(
                :name => "component"
            )
            comp.push file
            assert_nothing_raised {
                trans = comp.evaluate
            }
            assert_nothing_raised {
                trans.evaluate
            }
            #assert_nothing_raised {
            #    file.sync
            #}
            clearstorage
            Puppet::Type.allclear
        }
    end

    def test_recursion
        path = "/tmp/filerecursetest"
        tmpfile = File.join(path,"testing")
        system("mkdir -p #{path}")
        cyclefile(path)
        File.open(tmpfile, File::WRONLY|File::CREAT|File::APPEND) { |of|
            of.puts "yayness"
        }
        cyclefile(path)
        File.open(tmpfile, File::WRONLY|File::APPEND) { |of|
            of.puts "goodness"
        }
        cyclefile(path)
        @@tmpfiles.push path
    end

    def test_newchild
        path = "/tmp/newchilddir"
        @@tmpfiles.push path

        system("mkdir -p #{path}")
        File.open(File.join(path,"childtest"), "w") { |of|
            of.puts "yayness"
        }
        file = nil
        comp = nil
        trans = nil
        assert_nothing_raised {
            file = Puppet::Type::PFile.new(
                :name => path
            )
        }
        child = nil
        assert_nothing_raised {
            child = file.newchild("childtest")
        }
        assert(child)
        assert_nothing_raised {
            child = file.newchild("childtest")
        }
        assert(child)
        assert_raise(Puppet::DevError) {
            file.newchild(File.join(path,"childtest"))
        }
    end

    def test_simplelocalsource
        path = "/tmp/Filesourcetest"
        @@tmpfiles.push path
        system("mkdir -p #{path}")
        frompath = File.join(path,"source")
        topath = File.join(path,"dest")
        fromfile = nil
        tofile = nil
        trans = nil

        File.open(frompath, File::WRONLY|File::CREAT|File::APPEND) { |of|
            of.puts "yayness"
        }
        assert_nothing_raised {
            tofile = Puppet::Type::PFile.new(
                :name => topath,
                :source => frompath
            )
        }
        comp = Puppet::Component.new(
            :name => "component"
        )
        comp.push tofile
        assert_nothing_raised {
            trans = comp.evaluate
        }
        assert_nothing_raised {
            trans.evaluate
        }
        assert_nothing_raised {
            comp.sync
        }
        assert(FileTest.exists?(topath))
        from = File.open(frompath) { |o| o.read }
        to = File.open(topath) { |o| o.read }
        assert_equal(from,to)
        clearstorage
        Puppet::Type.allclear
        @@tmpfiles.push path
    end

    def randlist(list)
        num = rand(4)
        if num == 0
            num = 1
        end
        set = []

        ret = []
        num.times { |index|
            item = list[rand(list.length)]
            if set.include?(item)
                redo
            end

            ret.push item
        }
        return ret
    end

    def mkranddirsandfiles(dirs = nil,files = nil,depth = 3)
        if depth < 0
            return
        end

        unless dirs
            dirs = %w{This Is A Set Of Directories}
        end

        unless files
            files = %w{and this is a set of files}
        end

        tfiles = randlist(files)
        tdirs = randlist(dirs)

        tfiles.each { |file|
            File.open(file, "w") { |of|
                4.times {
                    of.puts rand(100)
                }
            }
        }

        tdirs.each { |dir|
            # it shouldn't already exist, but...
            unless FileTest.exists?(dir)
                Dir.mkdir(dir)
                FileUtils.cd(dir) {
                    mkranddirsandfiles(dirs,files,depth - 1)
                }
            end
        }
    end

    def file_list(dir)
        list = nil
        FileUtils.cd(dir) {
            list = %x{find . 2>/dev/null}.chomp.split(/\n/)
        }
        return list
    end

    def assert_trees_equal(fromdir,todir)
        assert(FileTest.directory?(fromdir))
        assert(FileTest.directory?(todir))

        # verify the file list is the same
        fromlist = nil
        FileUtils.cd(fromdir) {
            fromlist = %x{find . 2>/dev/null}.chomp.split(/\n/).reject { |file|
                ! FileTest.readable?(file)
            }
        }
        tolist = file_list(todir)

        assert_equal(fromlist,tolist)

        # and then do some verification that the files are actually set up
        # the same
        checked = 0
        fromlist.each_with_index { |file,i|
            fromfile = File.join(fromdir,file)
            tofile = File.join(todir,file)
            fromstat = File.stat(fromfile)
            tostat = File.stat(tofile)
            [:ftype,:gid,:mode,:uid].each { |method|
                assert_equal(
                    fromstat.send(method),
                    tostat.send(method)
                )

                next if fromstat.ftype == "directory"
                if checked < 10 and i % 3 == 0
                    from = File.open(fromfile) { |f| f.read }
                    to = File.open(tofile) { |f| f.read }

                    assert_equal(from,to)
                    checked += 1
                end
            }
        }
    end

    def random_files(dir)
        checked = 0
        list = file_list(dir)
        list.reverse.each_with_index { |file,i|
            path = File.join(dir,file)
            stat = File.stat(dir)
            if checked < 10 and (i % 3) == 2
                unless yield path
                    next
                end
                checked += 1
            end
        }
    end

    def delete_random_files(dir)
        random_files(dir) { |file|
            stat = File.stat(file)
            begin
                if stat.ftype == "directory"
                    false
                else
                    File.unlink(file)
                    true
                end
            rescue => detail
                # we probably won't be able to open our own secured files
                puts detail
                false
            end
        }
    end

    def add_random_files(dir)
        added = []
        random_files(dir) { |file|
            stat = File.stat(file)
            begin
                if stat.ftype == "directory"
                    name = File.join(file,"file" + rand(100).to_s)
                    File.open(name, "w") { |f|
                        f.puts rand(10)
                    }
                    added << name
                else
                    false
                end
            rescue => detail
                # we probably won't be able to open our own secured files
                puts detail
                false
            end
        }
        return added
    end

    def modify_random_files(dir)
        modded = []
        random_files(dir) { |file|
            stat = File.stat(file)
            begin
                if stat.ftype == "directory"
                    false
                else
                    File.open(file, "w") { |f|
                        f.puts rand(10)
                    }
                    modded << name
                    true
                end
            rescue => detail
                # we probably won't be able to open our own secured files
                puts detail
                false
            end
        }
        return modded
    end

    def readonly_random_files(dir)
        modded = []
        random_files(dir) { |file|
            stat = File.stat(file)
            begin
                if stat.ftype == "directory"
                    File.new(file).chmod(0111)
                else
                    File.new(file).chmod(0000)
                end
                modded << file
            rescue => detail
                # we probably won't be able to open our own secured files
                puts detail
                false
            end
        }
        return modded
    end

    def recursive_source_test(fromdir, todir)
        initstorage
        tofile = nil
        trans = nil

        assert_nothing_raised {
            tofile = Puppet::Type::PFile.new(
                :name => todir,
                "recurse" => true,
                "backup" => false,
                "source" => fromdir
            )
        }
        comp = Puppet::Component.new(
            :name => "component"
        )
        comp.push tofile
        assert_nothing_raised {
            trans = comp.evaluate
        }
        assert_nothing_raised {
            trans.evaluate
        }

        clearstorage
        Puppet::Type.allclear
    end

    def run_complex_sources
        path = "/tmp/ComplexSourcesTest"
        @@tmpfiles.push path

        # first create the source directory
        system("mkdir -p #{path}")


        # okay, let's create a directory structure
        fromdir = File.join(path,"fromdir")
        Dir.mkdir(fromdir)
        FileUtils.cd(fromdir) {
            mkranddirsandfiles()
        }

        todir = File.join(path, "todir")
        recursive_source_test(fromdir, todir)

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
        delete_random_files(todir)

        # and run
        recursive_source_test(fromdir, todir)

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_readonly_destfiles
        fromdir, todir = run_complex_sources
        readonly_random_files(todir)
        recursive_source_test(fromdir, todir)

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_modified_dest_files
        fromdir, todir = run_complex_sources

        # then modify some files
        modify_random_files(todir)

        recursive_source_test(fromdir, todir)

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_added_destfiles
        fromdir, todir = run_complex_sources
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

end
