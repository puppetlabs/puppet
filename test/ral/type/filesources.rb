#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/support/utils'
require 'cgi'
require 'fileutils'
require 'mocha'

class TestFileSources < Test::Unit::TestCase
    include PuppetTest::Support::Utils
    include PuppetTest::FileTesting
    def setup
        super
        if defined? @port
            @port += 1
        else
            @port = 12345
        end
        @file = Puppet::Type.type(:file)
        Puppet[:filetimeout] = -1
        Puppet::Util::SUIDManager.stubs(:asuser).yields 
    end

    def teardown
        super
        Puppet::Network::HttpPool.clear_http_instances
    end
    
    def use_storage
        begin
            initstorage
        rescue
            system("rm -rf %s" % Puppet[:statefile])
        end
    end

    def initstorage
        Puppet::Util::Storage.init
        Puppet::Util::Storage.load
    end
    
    # Make a simple recursive tree.
    def mk_sourcetree
        source = tempfile()
        sourcefile = File.join(source, "file")
        Dir.mkdir source
        File.open(sourcefile, "w") { |f| f.puts "yay" }
        
        dest = tempfile()
        destfile = File.join(dest, "file")
        return source, dest, sourcefile, destfile
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
        config = mk_catalog(file)
        child = nil
        assert_nothing_raised {
            child = file.newchild("childtest", true)
        }
        assert(child)
        assert_raise(Puppet::DevError) {
            file.newchild(File.join(path,"childtest"), true)
        }
    end
    
    def test_describe
        source = tempfile()
        dest = tempfile()
        
        file = Puppet::Type.newfile :path => dest, :source => source, :title => "copier"
        
        property = file.property(:source)
        
        # First try describing with a normal source
        result = nil
        assert_nothing_raised do
            result = property.describe(source)
        end
        assert_nil(result, "Got a result back when source is missing")
        
        # Now make a remote directory
        Dir.mkdir(source)
        assert_nothing_raised do
            result = property.describe(source)
        end
        assert_equal("directory", result[:type])
        
        # And as a file
        Dir.rmdir(source)
        File.open(source, "w") { |f| f.puts "yay" }
        assert_nothing_raised do
            result = property.describe(source)
        end
        assert_equal("file", result[:type])
        assert(result[:checksum], "did not get value for checksum")
        if Puppet::Util::SUIDManager.uid == 0
            assert(result.has_key?(:owner), "Lost owner in describe")
        else
            assert(! result.has_key?(:owner),
                "Kept owner in describe even tho not root")
        end
        
        # Now let's do the various link things
        File.unlink(source)
        target = tempfile()
        File.open(target, "w") { |f| f.puts "yay" }
        File.symlink(target, source)
        
        file[:links] = :manage
        assert_equal("link", property.describe(source)[:type])
        
        # And then make sure links get followed
        file[:links] = :follow
        assert_equal("file", property.describe(source)[:type])
    end
    
    def test_source_retrieve
        source = tempfile()
        dest = tempfile()
        
        file = Puppet::Type.newfile :path => dest, :source => source,
            :title => "copier"
        
        assert(file.property(:checksum), "source property did not create checksum property")
        property = file.property(:source)
        assert(property, "did not get source property")
        
        # Make sure the munge didn't actually change the source
        assert_equal([source], property.should, "munging changed the source")
        
        # First try it with a missing source
        currentvalue = nil
        assert_nothing_raised do
            currentvalue = property.retrieve
        end
        
        # And make sure the property considers itself in sync, since there's nothing
        # to do
        assert(property.insync?(currentvalue), "source thinks there's work to do with no file or dest")
        
        # Now make the dest a directory, and make sure the object sets :ensure
        # up to create a directory
        Dir.mkdir(source)
        assert_nothing_raised do
            currentvalue = property.retrieve
        end
        assert_equal(:directory, file.should(:ensure),
            "Did not set to create directory")
        
        # And make sure the source property won't try to do anything with a
        # remote dir
        assert(property.insync?(currentvalue), "Source was out of sync even tho remote is dir")
        
        # Now remove the source, and make sure :ensure was not modified
        Dir.rmdir(source)
        assert_nothing_raised do
            property.retrieve
        end
        assert_equal(:directory, file.should(:ensure),
            "Did not keep :ensure setting")
        
        # Now have a remote file and make sure things work correctly
        File.open(source, "w") { |f| f.puts "yay" }
        File.chmod(0755, source)
        
        assert_nothing_raised do
            property.retrieve
        end
        assert_equal(:file, file.should(:ensure),
            "Did not make correct :ensure setting")
        assert_equal(0755, file.should(:mode),
            "Mode was not copied over")
        
        # Now let's make sure that we get the first found source
        fake = tempfile()
        property.should = [fake, source]
        assert_nothing_raised do
            property.retrieve
        end
        assert_equal(Digest::MD5.hexdigest(File.read(source)), property.checksum.sub(/^\{\w+\}/, ''), 
            "Did not catch later source")
    end
    
    def test_insync
        source = tempfile()
        dest = tempfile()
        
        file = Puppet::Type.newfile :path => dest, :source => source,
            :title => "copier"
        
        property = file.property(:source)
        assert(property, "did not get source property")
        
        # Try it with no source at all
        currentvalues = file.retrieve
        assert(property.insync?(currentvalues[property]), "source property not in sync with missing source")

        # with a directory
        Dir.mkdir(source)
        currentvalues = file.retrieve
        assert(property.insync?(currentvalues[property]), "source property not in sync with directory as source")
        Dir.rmdir(source)
        
        # with a file
        File.open(source, "w") { |f| f.puts "yay" }
        currentvalues = file.retrieve
        assert(!property.insync?(currentvalues[property]), "source property was in sync when file was missing")
        
        # With a different file
        File.open(dest, "w") { |f| f.puts "foo" }
        currentvalues = file.retrieve
        assert(!property.insync?(currentvalues[property]), "source property was in sync with different file")
        
        # with matching files
        File.open(dest, "w") { |f| f.puts "yay" }
        currentvalues = file.retrieve
        assert(property.insync?(currentvalues[property]), "source property was not in sync with matching file")
    end
    
    def test_source_sync
        source = tempfile()
        dest = tempfile()

        file = Puppet::Type.newfile :path => dest, :source => source,
            :title => "copier"
        property = file.property(:source)
        
        File.open(source, "w") { |f| f.puts "yay" }
        
        currentvalues = file.retrieve
        assert(! property.insync?(currentvalues[property]), "source thinks it's in sync")
        
        event = nil
        assert_nothing_raised do
            event = property.sync
        end
        assert_equal(:file_created, event)
        assert_equal(File.read(source), File.read(dest),
            "File was not copied correctly")
        
        # Now write something different
        File.open(source, "w") { |f| f.puts "rah" }
        currentvalues = file.retrieve
        assert(! property.insync?(currentvalues[property]), "source should be out of sync")
        assert_nothing_raised do
            event = property.sync
        end
        assert_equal(:file_changed, event)
        assert_equal(File.read(source), File.read(dest),
            "File was not copied correctly")
    end
    
    # XXX This test doesn't cover everything.  Specifically,
    # it doesn't handle 'ignore' and 'links'.
    def test_sourcerecurse
        source, dest, sourcefile, destfile = mk_sourcetree
        
        # The sourcerecurse method will only ever get called when we're
        # recursing, so we go ahead and set it.
        obj = Puppet::Type.newfile :source => source, :path => dest, :recurse => true
        config = mk_catalog(obj)

        result = nil
        sourced = nil
        assert_nothing_raised do
            result, sourced = obj.sourcerecurse(true)
        end

        assert_equal([destfile], sourced, "Did not get correct list of sourced objects")
        dfileobj = @file[destfile]
        assert(dfileobj, "Did not create destfile object")
        assert_equal([dfileobj], result)
        
        # Clean this up so it can be recreated
        config.remove_resource(dfileobj)
        
        # Make sure we correctly iterate over the sources
        nosource = tempfile()
        obj[:source] = [nosource, source]

        result = nil
        assert_nothing_raised do
            result, sourced = obj.sourcerecurse(true)
        end
        assert_equal([destfile], sourced, "Did not get correct list of sourced objects")
        dfileobj = @file[destfile]
        assert(dfileobj, "Did not create destfile object with a missing source")
        assert_equal([dfileobj], result)
        dfileobj.remove
        
        # Lastly, make sure we return an empty array when no sources are there
        obj[:source] = [nosource, tempfile()]
        
        assert_nothing_raised do
            result, sourced = obj.sourcerecurse(true)
        end
        assert_equal([], sourced, "Did not get correct list of sourced objects")
        assert_equal([], result, "Sourcerecurse failed when all sources are missing")
    end

    def test_simplelocalsource
        path = tempfile()
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

        assert_apply(tofile)

        assert(FileTest.exists?(topath), "File #{topath} is missing")
        from = File.open(frompath) { |o| o.read }
        to = File.open(topath) { |o| o.read }
        assert_equal(from,to)
    end
    
    # Make sure a simple recursive copy works
    def test_simple_recursive_source
        source, dest, sourcefile, destfile = mk_sourcetree
        
        file = Puppet::Type.newfile :path => dest, :source => source, :recurse => true
        
        assert_events([:directory_created, :file_created], file)
        
        assert(FileTest.directory?(dest), "Dest dir was not created")
        assert(FileTest.file?(destfile), "dest file was not created")
        assert_equal("yay\n", File.read(destfile), "dest file was not copied correctly")
    end

    def recursive_source_test(fromdir, todir)
        Puppet::Type.allclear
        initstorage
        tofile = nil
        trans = nil

        assert_nothing_raised {
            tofile = Puppet.type(:file).create(
                :path => todir,
                :recurse => true,
                :backup => false,
                :source => fromdir
            )
        }
        assert_apply(tofile)

        assert(FileTest.exists?(todir), "Created dir %s does not exist" % todir)
        Puppet::Type.allclear
    end

    def run_complex_sources(networked = false)
        path = tempfile()

        # first create the source directory
        FileUtils.mkdir_p path

        # okay, let's create a directory structure
        fromdir = File.join(path,"fromdir")
        Dir.mkdir(fromdir)
        FileUtils.cd(fromdir) {
            File.open("one", "w") { |f| f.puts "onefile"}
            File.open("two", "w") { |f| f.puts "twofile"}
        }

        todir = File.join(path, "todir")
        source = fromdir
        if networked
            source = "puppet://localhost/%s%s" % [networked, fromdir]
        end
        recursive_source_test(source, todir)

        return [fromdir,todir, File.join(todir, "one"), File.join(todir, "two")]
    end

    def test_complex_sources_twice
        fromdir, todir, one, two = run_complex_sources
        assert_trees_equal(fromdir,todir)
        recursive_source_test(fromdir, todir)
        assert_trees_equal(fromdir,todir)
        # Now remove the whole tree and try it again.
        [one, two].each do |f| File.unlink(f) end
        Dir.rmdir(todir)
        recursive_source_test(fromdir, todir)
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_deleted_destfiles
        fromdir, todir, one, two = run_complex_sources
        assert(FileTest.exists?(todir))
        
        # We shouldn't have a 'two' file object in memory
        assert_nil(@file[two], "object for 'two' is still in memory")

        # then delete a file
        File.unlink(two)

        # and run
        recursive_source_test(fromdir, todir)

        assert(FileTest.exists?(two), "Deleted file was not recopied")

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_readonly_destfiles
        fromdir, todir, one, two = run_complex_sources
        assert(FileTest.exists?(todir))
        File.chmod(0600, one)
        recursive_source_test(fromdir, todir)

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
        
        # Now try it with the directory being read-only
        File.chmod(0111, todir)
        recursive_source_test(fromdir, todir)

        # and make sure they're still equal
        assert_trees_equal(fromdir,todir)
    end

    def test_sources_with_modified_dest_files
        fromdir, todir, one, two = run_complex_sources

        assert(FileTest.exists?(todir))
        
        # Modify a dest file
        File.open(two, "w") { |f| f.puts "something else" }

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

        assert(fromtree != totree, "Trees are incorrectly equal")

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

    # Make sure added files get correctly caught during recursion
    def test_RecursionWithAddedFiles
        basedir = tempfile()
        Dir.mkdir(basedir)
        @@tmpfiles << basedir
        file1 = File.join(basedir, "file1")
        file2 = File.join(basedir, "file2")
        subdir1 = File.join(basedir, "subdir1")
        file3 = File.join(subdir1, "file")
        File.open(file1, "w") { |f| f.puts "yay" }
        rootobj = nil
        assert_nothing_raised {
            rootobj = Puppet.type(:file).create(
                :name => basedir,
                :recurse => true,
                :check => %w{type owner},
                :mode => 0755
            )
        }
        
        assert_apply(rootobj)
        assert_equal(0755, filemode(file1))

        File.open(file2, "w") { |f| f.puts "rah" }
        assert_apply(rootobj)
        assert_equal(0755, filemode(file2))

        Dir.mkdir(subdir1)
        File.open(file3, "w") { |f| f.puts "foo" }
        assert_apply(rootobj)
        assert_equal(0755, filemode(file3))
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

    def test_NetworkSources
        server = nil
        mounts = {
            "/" => "root"
        }

        fileserverconf = mkfileserverconf(mounts)

        Puppet[:autosign] = true

        Puppet[:masterport] = 8762
        Puppet[:name] = "puppetmasterd"
        Puppet[:certdnsnames] = "localhost"

        serverpid = nil
        assert_nothing_raised() {
            server = Puppet::Network::HTTPServer::WEBrick.new(
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

    def test_unmountedNetworkSources
        server = nil
        mounts = {
            "/" => "root",
            "/noexistokay" => "noexist"
        }

        fileserverconf = mkfileserverconf(mounts)

        Puppet[:autosign] = true
        Puppet[:masterport] = @port
        Puppet[:certdnsnames] = "localhost"

        serverpid = nil
        assert_nothing_raised("Could not start on port %s" % @port) {
            server = Puppet::Network::HTTPServer::WEBrick.new(
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

        comp = mk_catalog(file)
        comp.apply

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

        currentvalue = file.retrieve

        assert(currentvalue[file.property(:checksum)], 
               "File does not have a checksum property")

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

        comp = mk_catalog(file)
        assert_events([:file_created], comp)

        assert(File.exists?(to), "File does not exist")

        txt = nil
        File.open(to) { |f| txt = f.read.chomp }

        assert_equal("yee-haw", txt, "Contents do not match")
    end

    # Make sure that source-copying updates the checksum on the same run
    def test_checksumchange
        source = tempfile()
        dest = tempfile()
        File.open(dest, "w") { |f| f.puts "boo" }
        File.open(source, "w") { |f| f.puts "yay" }

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :name => dest,
                :source => source
            )
        }

        file.retrieve

        assert_events([:file_changed], file)
        file.retrieve
        assert_events([], file)
    end

    # Make sure that source-copying updates the checksum on the same run
    def test_sourcebeatsensure
        source = tempfile()
        dest = tempfile()
        File.open(source, "w") { |f| f.puts "yay" }

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :name => dest,
                :ensure => "file",
                :source => source
            )
        }

        file.retrieve

        assert_events([:file_created], file)
        file.retrieve
        assert_events([], file)
        assert_events([], file)
    end

    def test_sourcewithlinks
        source = tempfile()
        link = tempfile()
        dest = tempfile()

        File.open(source, "w") { |f| f.puts "yay" }
        File.symlink(source, link)

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :name => dest,
                :source => link,
                :links => :follow
            )
        }

        assert_events([:file_created], file)
        assert(FileTest.file?(dest), "Destination is not a file")

        # Now copy the links
        file[:links] = :manage
        assert_events([:link_created], file)
        assert(FileTest.symlink?(dest), "Destination is not a link")
    end

    def test_changes
        source = tempfile()
        dest = tempfile()

        File.open(source, "w") { |f| f.puts "yay" }

        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:file).create(
                :name => dest,
                :source => source
            )
        }

        assert_events([:file_created], obj)
        assert_equal(File.read(source), File.read(dest), "Files are not equal")
        assert_events([], obj)

        File.open(source, "w") { |f| f.puts "boo" }

        assert_events([:file_changed], obj)
        assert_equal(File.read(source), File.read(dest), "Files are not equal")
        assert_events([], obj)

        File.open(dest, "w") { |f| f.puts "kaboom" }

        # There are two changes, because first the checksum is noticed, and
        # then the source causes a change
        assert_events([:file_changed, :file_changed], obj)
        assert_equal(File.read(source), File.read(dest), "Files are not equal")
        assert_events([], obj)
    end

    def test_file_source_with_space
        dir = tempfile()
        source = File.join(dir, "file with spaces")
        Dir.mkdir(dir)
        File.open(source, "w") { |f| f.puts "yayness" }

        newdir = tempfile()
        newpath = File.join(newdir, "file with spaces")

        file = Puppet::Type.newfile(
            :path => newdir,
            :source => dir,
            :recurse => true
        )


        assert_apply(file)

        assert(FileTest.exists?(newpath), "Did not create file")
        assert_equal("yayness\n", File.read(newpath))
    end

    # Make sure files aren't replaced when replace is false, but otherwise
    # are.
    def test_replace
        source = tempfile()
        File.open(source, "w") { |f| f.puts "yayness" }

        dest = tempfile()
        file = Puppet::Type.newfile(
            :path => dest,
            :source => source,
            :recurse => true
        )


        assert_apply(file)

        assert(FileTest.exists?(dest), "Did not create file")
        assert_equal("yayness\n", File.read(dest))

        # Now set :replace
        assert_nothing_raised {
            file[:replace] = false
        }

        File.open(source, "w") { |f| f.puts "funtest" }
        assert_apply(file)

        # Make sure it doesn't change.
        assert_equal("yayness\n", File.read(dest),
            "File got replaced when :replace was false")

        # Now set it to true and make sure it does change.
        assert_nothing_raised {
            file[:replace] = true
        }
        assert_apply(file)

        # Make sure it doesn't change.
        assert_equal("funtest\n", File.read(dest),
            "File was not replaced when :replace was true")
    end

    # Testing #285.  This just makes sure that URI parsing works correctly.
    def test_fileswithpoundsigns
        dir = tstdir()
        subdir = File.join(dir, "#dir")
        Dir.mkdir(subdir)
        file = File.join(subdir, "file")
        File.open(file, "w") { |f| f.puts "yayness" }

        dest = tempfile()
        source = "file://localhost#{dir}"
        obj = Puppet::Type.newfile(
            :path => dest,
            :source => source,
            :recurse => true
        )

        newfile = File.join(dest, "#dir", "file")

        poundsource = "file://localhost#{subdir}"

        sourceobj = path = nil
        assert_nothing_raised {
            sourceobj, path = obj.uri2obj(poundsource)
        }

        assert_equal("/localhost" + URI.escape(subdir), path)

        assert_apply(obj)

        assert(FileTest.exists?(newfile), "File did not get created")
        assert_equal("yayness\n", File.read(newfile))
    end

    def test_sourceselect
        dest = tempfile()
        sources = []
        2.times { |i|
            i = i + 1
            source = tempfile()
            sources << source
            file = File.join(source, "file%s" % i)
            Dir.mkdir(source)
            File.open(file, "w") { |f| f.print "yay" }
        }
        file1 = File.join(dest, "file1")
        file2 = File.join(dest, "file2")
        file3 = File.join(dest, "file3")

        # Now make different files with the same name in each source dir
        sources.each_with_index do |source, i|
            File.open(File.join(source, "file3"), "w") { |f|
                f.print i.to_s
            }
        end

        obj = Puppet::Type.newfile(:path => dest, :recurse => true,
            :source => sources)

        assert_equal(:first, obj[:sourceselect], "sourceselect has the wrong default")
        # First, make sure we default to just copying file1
        assert_apply(obj)

        assert(FileTest.exists?(file1), "File from source 1 was not copied")
        assert(! FileTest.exists?(file2), "File from source 2 was copied")
        assert(FileTest.exists?(file3), "File from source 1 was not copied")
        assert_equal("0", File.read(file3), "file3 got wrong contents")

        # Now reset sourceselect
        assert_nothing_raised do
            obj[:sourceselect] = :all
        end
        File.unlink(file1)
        File.unlink(file3)
        Puppet.err :yay
        assert_apply(obj)

        assert(FileTest.exists?(file1), "File from source 1 was not copied")
        assert(FileTest.exists?(file2), "File from source 2 was copied")
        assert(FileTest.exists?(file3), "File from source 1 was not copied")
        assert_equal("0", File.read(file3), "file3 got wrong contents")
    end
    
    def test_recursive_sourceselect
        dest = tempfile()
        source1 = tempfile()
        source2 = tempfile()
        files = []
        [source1, source2, File.join(source1, "subdir"), File.join(source2, "subdir")].each_with_index do |dir, i|
            Dir.mkdir(dir)
            # Make a single file in each directory
            file = File.join(dir, "file%s" % i)
            File.open(file, "w") { |f| f.puts "yay%s" % i}

            # Now make a second one in each directory
            file = File.join(dir, "second-file%s" % i)
            File.open(file, "w") { |f| f.puts "yaysecond-%s" % i}
            files << file
        end
        
        obj = Puppet::Type.newfile(:path => dest, :source => [source1, source2], :sourceselect => :all, :recurse => true)
        
        assert_apply(obj)
        
        ["file0", "file1", "second-file0", "second-file1", "subdir/file2", "subdir/second-file2", "subdir/file3", "subdir/second-file3"].each do |file|
            path = File.join(dest, file)
            assert(FileTest.exists?(path), "did not create %s" % file)
            
            assert_equal("yay%s\n" % File.basename(file).sub("file", ''), File.read(path), "file was not copied correctly")
        end
    end

    # #594
    def test_purging_missing_remote_files
        source = tempfile()
        dest = tempfile()
        s1 = File.join(source, "file1")
        s2 = File.join(source, "file2")
        d1 = File.join(dest, "file1")
        d2 = File.join(dest, "file2")
        Dir.mkdir(source)
        [s1, s2].each { |name| File.open(name, "w") { |file| file.puts "something" } }

        # We have to add a second parameter, because that's the only way to expose the "bug".
        file = Puppet::Type.newfile(:path => dest, :source => source, :recurse => true, :purge => true, :mode => "755")

        assert_apply(file)

        assert(FileTest.exists?(d1), "File1 was not copied")
        assert(FileTest.exists?(d2), "File2 was not copied")

        File.unlink(s2)

        assert_apply(file)

        assert(FileTest.exists?(d1), "File1 was not kept")
        assert(! FileTest.exists?(d2), "File2 was not purged")
    end
end

