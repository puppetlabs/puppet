#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/support/utils'
require 'fileutils'

class TestFile < Test::Unit::TestCase
    include PuppetTest::Support::Utils
    include PuppetTest::FileTesting

    def mkfile(hash)
        file = nil
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(hash)
        }
        return file
    end

    def mktestfile
        tmpfile = tempfile()
        File.open(tmpfile, "w") { |f| f.puts rand(100) }
        @@tmpfiles.push tmpfile
        mkfile(:name => tmpfile)
    end

    def setup
        super
        @file = Puppet::Type.type(:file)
        $method = @method_name
        Puppet[:filetimeout] = -1
        Facter.stubs(:to_hash).returns({})
    end

    def teardown
        system("rm -rf %s" % Puppet[:statefile])
        super
    end

    def initstorage
        Puppet::Util::Storage.init
        Puppet::Util::Storage.load
    end

    def clearstorage
        Puppet::Util::Storage.store
        Puppet::Util::Storage.clear
    end

    def test_owner
        file = mktestfile()

        users = {}
        count = 0

        # collect five users
        Etc.passwd { |passwd|
            if count > 5
                break
            else
                count += 1
            end
            users[passwd.uid] = passwd.name
        }

        fake = {}
        # find a fake user
        while true
            a = rand(1000)
            begin
                Etc.getpwuid(a)
            rescue
                fake[a] = "fakeuser"
                break
            end
        end

        uid, name = users.shift
        us = {}
        us[uid] = name
        users.each { |uid, name|
            assert_apply(file)
            assert_nothing_raised() {
                file[:owner] = name
            }
            assert_nothing_raised() {
                file.retrieve
            }
            assert_apply(file)
        }
    end

    def test_group
        file = mktestfile()
        [%x{groups}.chomp.split(/ /), Process.groups].flatten.each { |group|
            assert_nothing_raised() {
                file[:group] = group
            }
            assert(file.property(:group))
            assert(file.property(:group).should)
        }
    end

    def test_groups_fails_when_invalid
        assert_raise(Puppet::Error, "did not fail when the group was empty") do
            Puppet::Type.type(:file).new :path => "/some/file", :group => ""
        end
    end

    if Puppet::Util::SUIDManager.uid == 0
        def test_createasuser
            dir = tmpdir()

            user = nonrootuser()
            path = File.join(tmpdir, "createusertesting")
            @@tmpfiles << path

            file = nil
            assert_nothing_raised {
                file = Puppet::Type.type(:file).new(
                    :path => path,
                    :owner => user.name,
                    :ensure => "file",
                    :mode => "755"
                )
            }

            comp = mk_catalog("createusertest", file)

            assert_events([:file_created], comp)
        end

        def test_nofollowlinks
            basedir = tempfile()
            Dir.mkdir(basedir)
            file = File.join(basedir, "file")
            link = File.join(basedir, "link")

            File.open(file, "w", 0644) { |f| f.puts "yayness"; f.flush }
            File.symlink(file, link)

            # First test 'user'
            user = nonrootuser()

            inituser = File.lstat(link).uid
            File.lchown(inituser, nil, link)

            obj = nil
            assert_nothing_raised {
                obj = Puppet::Type.type(:file).new(
                    :title => link,
                    :owner => user.name
                )
            }
            obj.retrieve

            # Make sure it defaults to managing the link
            assert_events([:file_changed], obj)
            assert_equal(user.uid, File.lstat(link).uid)
            assert_equal(inituser, File.stat(file).uid)
            File.chown(inituser, nil, file)
            File.lchown(inituser, nil, link)

            # Try following
            obj[:links] = :follow
            assert_events([:file_changed], obj)
            assert_equal(user.uid, File.stat(file).uid)
            assert_equal(inituser, File.lstat(link).uid)

            # And then explicitly managing
            File.chown(inituser, nil, file)
            File.lchown(inituser, nil, link)
            obj[:links] = :manage
            assert_events([:file_changed], obj)
            assert_equal(user.uid, File.lstat(link).uid)
            assert_equal(inituser, File.stat(file).uid)

            obj.delete(:owner)
            obj[:links] = :follow

            # And then test 'group'
            group = nonrootgroup

            initgroup = File.stat(file).gid
            obj[:group] = group.name

            obj[:links] = :follow
            assert_events([:file_changed], obj)
            assert_equal(group.gid, File.stat(file).gid)
            File.chown(nil, initgroup, file)
            File.lchown(nil, initgroup, link)

            obj[:links] = :manage
            assert_events([:file_changed], obj)
            assert_equal(group.gid, File.lstat(link).gid)
            assert_equal(initgroup, File.stat(file).gid)
        end

        def test_ownerasroot
            file = mktestfile()

            users = {}
            count = 0

            # collect five users
            Etc.passwd { |passwd|
                if count > 5
                    break
                else
                    count += 1
                end
                next if passwd.uid < 0
                users[passwd.uid] = passwd.name
            }

            fake = {}
            # find a fake user
            while true
                a = rand(1000)
                begin
                    Etc.getpwuid(a)
                rescue
                    fake[a] = "fakeuser"
                    break
                end
            end

            users.each { |uid, name|
                assert_nothing_raised() {
                    file[:owner] = name
                }
                changes = []
                assert_nothing_raised() {
                    changes << file.evaluate
                }
                assert(changes.length > 0)
                assert_apply(file)
                currentvalue = file.retrieve
                assert(file.insync?(currentvalue))
                assert_nothing_raised() {
                    file[:owner] = uid
                }
                assert_apply(file)
                currentvalue = file.retrieve
                # make sure changing to number doesn't cause a sync
                assert(file.insync?(currentvalue))
            }

            # We no longer raise an error here, because we check at run time
            #fake.each { |uid, name|
            #    assert_raise(Puppet::Error) {
            #        file[:owner] = name
            #    }
            #    assert_raise(Puppet::Error) {
            #        file[:owner] = uid
            #    }
            #}
        end

        def test_groupasroot
            file = mktestfile()
            [%x{groups}.chomp.split(/ /), Process.groups].flatten.each { |group|
                next unless Puppet::Util.gid(group) # grr.
                assert_nothing_raised() {
                    file[:group] = group
                }
                assert(file.property(:group))
                assert(file.property(:group).should)
                assert_apply(file)
                currentvalue = file.retrieve
                assert(file.insync?(currentvalue))
                assert_nothing_raised() {
                    file.delete(:group)
                }
            }
        end

        if Facter.value(:operatingsystem) == "Darwin"
            def test_sillyowner
                file = tempfile()
                File.open(file, "w") { |f| f.puts "" }
                File.chown(-2, nil, file)

                assert(File.stat(file).uid > 120000, "eh?")
                user = nonrootuser
                obj = Puppet::Type.newfile(
                    :path => file,
                    :owner => user.name
                )

                assert_apply(obj)

                assert_equal(user.uid, File.stat(file).uid)
            end
        end
    else
        $stderr.puts "Run as root for complete owner and group testing"
    end

    def test_create
        %w{a b c d}.collect { |name| tempfile() + name.to_s }.each { |path|
            file =nil
            assert_nothing_raised() {
                file = Puppet::Type.type(:file).new(
                    :name => path,
                    :ensure => "file"
                )
            }
            assert_events([:file_created], file)
            assert_events([], file)
            assert(FileTest.file?(path), "File does not exist")
            assert(file.insync?(file.retrieve))
            @@tmpfiles.push path
        }
    end

    def test_create_dir
        basedir = tempfile()
        Dir.mkdir(basedir)
        %w{a b c d}.collect { |name| "#{basedir}/%s" % name }.each { |path|
            file = nil
            assert_nothing_raised() {
                file = Puppet::Type.type(:file).new(
                    :name => path,
                    :ensure => "directory"
                )
            }
            assert(! FileTest.directory?(path), "Directory %s already exists" %
                [path])
            assert_events([:directory_created], file)
            assert_events([], file)
            assert(file.insync?(file.retrieve))
            assert(FileTest.directory?(path))
            @@tmpfiles.push path
        }
    end

    def test_modes
        file = mktestfile
        # Set it to something else initially
        File.chmod(0775, file.title)
        [0644,0755,0777,0641].each { |mode|
            assert_nothing_raised() {
                file[:mode] = mode
            }
            assert_events([:file_changed], file)
            assert_events([], file)

            assert(file.insync?(file.retrieve))

            assert_nothing_raised() {
                file.delete(:mode)
            }
        }
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
                file = Puppet::Type.type(:file).new(
                    param => path,
                    :recurse => true,
                    :checksum => "md5"
                )
            }
            comp = Puppet::Type.type(:component).new(
                :name => "component"
            )
            comp.push file
            assert_nothing_raised {
                trans = comp.evaluate
            }
            assert_nothing_raised {
                trans.evaluate
            }
            clearstorage
            Puppet::Type.allclear
        }
    end
    
    def test_recurse?
        file = Puppet::Type.type(:file).new :path => tempfile
        
        # Make sure we default to false
        assert(! file.recurse?, "Recurse defaulted to true")
        
        [true, "true", 10, "inf", "remote"].each do |value|
            file[:recurse] = value
            assert(file.recurse?, "%s did not cause recursion" % value)
        end
        
        [false, "false", 0].each do |value|
            file[:recurse] = value
            assert(! file.recurse?, "%s caused recursion" % value)
        end
    end
    
    def test_recursion
        basedir = tempfile()
        subdir = File.join(basedir, "subdir")
        tmpfile = File.join(basedir,"testing")
        FileUtils.mkdir_p(subdir)

        dir = nil
        [true, "true", "inf", 50].each do |value|
            assert_nothing_raised {
                dir = Puppet::Type.type(:file).new(
                    :path => basedir,
                    :recurse => value,
                    :check => %w{owner mode group}
                )
            }
            config = mk_catalog dir
            transaction = Puppet::Transaction.new(config)
            
            children = nil

            assert_nothing_raised {
                children = transaction.eval_generate(dir)
            }
            
            assert_equal([subdir], children.collect {|c| c.title },
                "Incorrect generated children")
            
            # Remove our subdir resource, 
            subdir_resource = config.resource(:file, subdir)
            config.remove_resource(subdir_resource)

            # Create the test file
            File.open(tmpfile, "w") { |f| f.puts "yayness" }
            
            assert_nothing_raised {
                children = transaction.eval_generate(dir)
            }

            # And make sure we get both resources back.
            assert_equal([subdir, tmpfile].sort, children.collect {|c| c.title }.sort,
                "Incorrect generated children when recurse == %s" % value.inspect)
            
            File.unlink(tmpfile)
        end
    end

    def test_filetype_retrieval
        file = nil

        # Verify it retrieves files of type directory
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :name => tmpdir(),
                :check => :type
            )
        }

        assert_nothing_raised {
            file.evaluate
        }

        assert_equal("directory", file.property(:type).retrieve)

        # And then check files
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :name => tempfile(),
                :ensure => "file"
            )
        }

        assert_apply(file)
        file[:check] = "type"
        assert_apply(file)

        assert_equal("file", file.property(:type).retrieve)

        file[:type] = "directory"

        currentvalues = {}
        assert_nothing_raised { currentvalues = file.retrieve }

        # The 'retrieve' method sets @should to @is, so they're never
        # out of sync.  It's a read-only class.
        assert(file.insync?(currentvalues))
    end

    def test_path
        dir = tempfile()

        path = File.join(dir, "subdir")

        assert_nothing_raised("Could not make file") {
            FileUtils.mkdir_p(File.dirname(path))
            File.open(path, "w") { |f| f.puts "yayness" }
        }

        file = nil
        dirobj = nil
        assert_nothing_raised("Could not make file object") {
            dirobj = Puppet::Type.type(:file).new(
                :path => dir,
                :recurse => true,
                :check => %w{mode owner group}
            )
        }
        catalog = mk_catalog dirobj
        transaction = Puppet::Transaction.new(catalog)
        transaction.eval_generate(dirobj)

        #assert_nothing_raised {
        #    dirobj.eval_generate
        #}

        file = catalog.resource(:file, path)

        assert(file, "Could not retrieve file object")

        assert_equal("/%s" % file.ref, file.path)
    end

    def test_autorequire
        basedir = tempfile()
        subfile = File.join(basedir, "subfile")

        baseobj = Puppet::Type.type(:file).new(
            :name => basedir,
            :ensure => "directory"
        )

        subobj = Puppet::Type.type(:file).new(
            :name => subfile,
            :ensure => "file"
        )
        catalog = mk_catalog(baseobj, subobj)
        edge = nil
        assert_nothing_raised do
            edge = subobj.autorequire.shift
        end
        assert_equal(baseobj, edge.source, "file did not require its parent dir")
        assert_equal(subobj, edge.target, "file did not require its parent dir")
    end

    # Unfortunately, I know this fails
    def disabled_test_recursivemkdir
        path = tempfile()
        subpath = File.join(path, "this", "is", "a", "dir")
        file = nil
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :name => subpath,
                :ensure => "directory",
                :recurse => true
            )
        }

        comp = mk_catalog("yay", file)
        comp.finalize
        assert_apply(comp)
        #assert_events([:directory_created], comp)

        assert(FileTest.directory?(subpath), "Did not create directory")
    end

    # Make sure that content updates the checksum on the same run
    def test_checksumchange_for_content
        dest = tempfile()
        File.open(dest, "w") { |f| f.puts "yayness" }

        file = nil
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :name => dest,
                :checksum => "md5",
                :content => "This is some content"
            )
        }

        file.retrieve

        assert_events([:file_changed], file)
        file.retrieve
        assert_events([], file)
    end

    # Make sure that content updates the checksum on the same run
    def test_checksumchange_for_ensure
        dest = tempfile()

        file = nil
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :name => dest,
                :checksum => "md5",
                :ensure => "file"
            )
        }

        file.retrieve

        assert_events([:file_created], file)
        file.retrieve
        assert_events([], file)
    end

    def test_nameandpath
        path = tempfile()

        file = nil
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :title => "fileness",
                :path => path,
                :content => "this is some content"
            )
        }

        assert_apply(file)

        assert(FileTest.exists?(path))
    end

    # Make sure that a missing group isn't fatal at object instantiation time.
    def test_missinggroup
        file = nil
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :path => tempfile(),
                :group => "fakegroup"
            )
        }

        assert(file.property(:group), "Group property failed")
    end

    def test_modecreation
        path = tempfile()
        file = Puppet::Type.type(:file).new(
            :path => path,
            :ensure => "file",
            :mode => "0777"
        )
        assert_equal(0777, file.should(:mode),
            "Mode did not get set correctly")
        assert_apply(file)
        assert_equal(0777, File.stat(path).mode & 007777,
            "file mode is incorrect")
        File.unlink(path)
        file[:ensure] = "directory"
        assert_apply(file)
        assert_equal(0777, File.stat(path).mode & 007777,
            "directory mode is incorrect")
    end

    # If both 'ensure' and 'content' are used, make sure that all of the other
    # properties are handled correctly.
    def test_contentwithmode
        path = tempfile()

        file = nil
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :path => path,
                :ensure => "file",
                :content => "some text\n",
                :mode => 0755
            )
        }

        assert_apply(file)
        assert_equal("%o" % 0755, "%o" % (File.stat(path).mode & 007777))
    end

    def test_backupmodes
        File.umask(0022)
        
        file = tempfile()
        newfile = tempfile()

        File.open(file, "w", 0411) { |f| f.puts "yayness" }

        obj = Puppet::Type.type(:file).new(
            :path => file, :content => "rahness\n", :backup => ".puppet-bak"
        )
        catalog = mk_catalog(obj)
        catalog.apply

        backupfile = file + obj[:backup]
        @@tmpfiles << backupfile
        assert(FileTest.exists?(backupfile),
            "Backup file %s does not exist" % backupfile)

        assert_equal(0411, filemode(backupfile),
            "File mode is wrong for backupfile")

        name = "bucket"
        bpath = tempfile()
        Dir.mkdir(bpath)
        bucket = Puppet::Type.type(:filebucket).new(:title => name, :path => bpath)
        catalog.add_resource(bucket)

        obj[:backup] = name
        obj[:content] = "New content"
        catalog.finalize
        catalog.apply

        md5 = "18cc17fa3047fcc691fdf49c0a7f539a"
        dir, file, pathfile = Puppet::Network::Handler.filebucket.paths(bpath, md5)

        assert_equal(0440, filemode(file))
    end

    def test_replacefilewithlink
        path = tempfile()
        link = tempfile()

        File.open(path, "w") { |f| f.puts "yay" }
        File.open(link, "w") { |f| f.puts "a file" }

        file = nil
        assert_nothing_raised {
            file = Puppet::Type.type(:file).new(
                :ensure => path,
                :path => link
            )
        }

        assert_events([:link_created], file)

        assert(FileTest.symlink?(link), "Link was not created")

        assert_equal(path, File.readlink(link), "Link was created incorrectly")
    end

    def test_file_with_spaces
        dir = tempfile()
        Dir.mkdir(dir)
        source = File.join(dir, "file spaces")
        dest = File.join(dir, "another space")

        File.open(source, "w") { |f| f.puts :yay }
        obj = Puppet::Type.type(:file).new(
            :path => dest,
            :source => source
        )
        assert(obj, "Did not create file")

        assert_apply(obj)

        assert(FileTest.exists?(dest), "File did not get created")
    end

    # Testing #274.  Make sure target can be used without 'ensure'.
    def test_target_without_ensure
        source = tempfile()
        dest = tempfile()
        File.open(source, "w") { |f| f.puts "funtest" }

        obj = nil
        assert_nothing_raised {
            obj = Puppet::Type.newfile(:path => dest, :target => source)
        }

        assert_apply(obj)
    end

    def test_autorequire_owner_and_group
        file = tempfile()
        comp = nil
        user = nil
        group =nil
        home = nil
        ogroup = nil
        assert_nothing_raised {
            user = Puppet::Type.type(:user).new(
                :name => "pptestu",
                :home => file,
                :gid => "pptestg"
            )
            home = Puppet::Type.type(:file).new(
                :path => file,
                :owner => "pptestu",
                :group => "pptestg",
                :ensure => "directory"
            )
            group = Puppet::Type.type(:group).new(
                :name => "pptestg"
            )
            comp = mk_catalog(user, group, home)
        }
        
        # Now make sure we get a relationship for each of these
        rels = nil
        assert_nothing_raised { rels = home.autorequire }
        assert(rels.detect { |e| e.source == user }, "owner was not autorequired")
        assert(rels.detect { |e| e.source == group }, "group was not autorequired")
    end

    # Testing #309 -- //my/file => /my/file
    def test_slash_deduplication
        ["/my/////file/for//testing", "//my/file/for/testing///",
            "/my/file/for/testing"].each do |path|
            file = nil
            assert_nothing_raised do
                file = Puppet::Type.newfile(:path => path)
            end

            assert_equal("/my/file/for/testing", file.title)
        end
    end

    # Testing #304
    def test_links_to_directories
        link = tempfile()
        file = tempfile()
        dir = tempfile()
        Dir.mkdir(dir)

        bucket = Puppet::Type.type(:filebucket).new :name => "main"
        File.symlink(dir, link)
        File.open(file, "w") { |f| f.puts "" }
        assert_equal(dir, File.readlink(link))
        obj = Puppet::Type.newfile :path => link, :ensure => :link, :target => file, :recurse => false, :backup => "main"

        catalog = mk_catalog(bucket, obj)

        catalog.apply

        assert_equal(file, File.readlink(link))
    end

    # Testing #303
    def test_nobackups_with_links
        link = tempfile()
        new = tempfile()

        File.open(link, "w") { |f| f.puts "old" }
        File.open(new, "w") { |f| f.puts "new" }
        obj = Puppet::Type.newfile :path => link, :ensure => :link,
            :target => new, :recurse => true, :backup => false

        assert_nothing_raised do
            obj.handlebackup
        end

        bfile = [link, "puppet-bak"].join(".")

        assert(! FileTest.exists?(bfile), "Backed up when told not to")

        assert_apply(obj)

        assert(! FileTest.exists?(bfile), "Backed up when told not to")
    end

    # Make sure we consistently handle backups for all cases.
    def test_ensure_with_backups
        # We've got three file types, so make sure we can replace any type
        # with the other type and that backups are done correctly.
        types = [:file, :directory, :link]

        dir = tempfile()
        path = File.join(dir, "test")
        linkdest = tempfile()
        creators = {
            :file => proc { File.open(path, "w") { |f| f.puts "initial" } },
            :directory => proc { Dir.mkdir(path) },
            :link => proc { File.symlink(linkdest, path) }
        }

        bucket = Puppet::Type.type(:filebucket).new :name => "main", :path => tempfile()

        obj = Puppet::Type.newfile :path => path, :force => true,
            :links => :manage

        catalog = mk_catalog(obj, bucket)

        Puppet[:trace] = true
        ["main", false].each do |backup|
            obj[:backup] = backup
            obj.finish
            types.each do |should|
                types.each do |is|
                    # It makes no sense to replace a directory with a directory
                    # next if should == :directory and is == :directory

                    Dir.mkdir(dir)

                    # Make the thing
                    creators[is].call

                    obj[:ensure] = should

                    if should == :link
                        obj[:target] = linkdest
                    else
                        if obj.property(:target)
                            obj.delete(:target)
                        end
                    end

                    # First try just removing the initial data
                    assert_nothing_raised do
                        obj.remove_existing(should)
                    end

                    unless is == should
                        # Make sure the original is gone
                        assert(! FileTest.exists?(obj[:path]),
                            "remove_existing did not work: " +
                            "did not remove %s with %s" % [is, should])
                    end
                    FileUtils.rmtree(obj[:path])

                    # Now make it again
                    creators[is].call

                    property = obj.property(:ensure)

                    currentvalue = property.retrieve
                    unless property.insync?(currentvalue)
                        assert_nothing_raised do
                            property.sync
                        end
                    end
                    FileUtils.rmtree(dir)
                end
            end
        end
    end
    
    if Process.uid == 0
    # Testing #364.
    def test_writing_in_directories_with_no_write_access
        # Make a directory that our user does not have access to
        dir = tempfile()
        Dir.mkdir(dir)
        
        # Get a fake user
        user = nonrootuser
        # and group
        group = nonrootgroup
        
        # First try putting a file in there
        path = File.join(dir, "file")
        file = Puppet::Type.newfile :path => path, :owner => user.name, :group => group.name, :content => "testing"
        
        # Make sure we can create it
        assert_apply(file)
        assert(FileTest.exists?(path), "File did not get created")
        # And that it's owned correctly
        assert_equal(user.uid, File.stat(path).uid, "File has the wrong owner")
        assert_equal(group.gid, File.stat(path).gid, "File has the wrong group")

        assert_equal("testing", File.read(path), "file has the wrong content")
        
        # Now make a dir
        subpath = File.join(dir, "subdir")
        subdir = Puppet::Type.newfile :path => subpath, :owner => user.name, :group => group.name, :ensure => :directory
        # Make sure we can create it
        assert_apply(subdir)
        assert(FileTest.directory?(subpath), "File did not get created")
        # And that it's owned correctly
        assert_equal(user.uid, File.stat(subpath).uid, "File has the wrong owner")
        assert_equal(group.gid, File.stat(subpath).gid, "File has the wrong group")

        assert_equal("testing", File.read(path), "file has the wrong content")
    end
    end
    
    # #366
    def test_replace_aliases
        file = Puppet::Type.newfile :path => tempfile()
        file[:replace] = :yes
        assert_equal(:true, file[:replace], ":replace did not alias :true to :yes")
        file[:replace] = :no
        assert_equal(:false, file[:replace], ":replace did not alias :false to :no")
    end
    
    def test_backup
        path = tempfile()
        file = Puppet::Type.newfile :path => path, :content => "yay"

        catalog = mk_catalog(file)
        catalog.finalize # adds the default resources.
        
        [false, :false, "false"].each do |val|
            assert_nothing_raised do
                file[:backup] = val
            end
            assert_equal(false, file[:backup], "%s did not translate" % val.inspect)
        end
        [true, :true, "true", ".puppet-bak"].each do |val|
            assert_nothing_raised do
                file[:backup] = val
            end
            assert_equal(".puppet-bak", file[:backup], "%s did not translate" % val.inspect)
        end
        
        # Now try a non-bucket string
        assert_nothing_raised do
            file[:backup] = ".bak"
        end
        assert_equal(".bak", file[:backup], ".bak did not translate")
        
        # Now try a non-existent bucket
        assert_nothing_raised do
            file[:backup] = "main"
        end
        assert_equal("main", file[:backup], "bucket name was not retained")
        assert_equal("main", file.bucket, "file's bucket was not set")
        
        # And then an existing bucket
        obj = Puppet::Type.type(:filebucket).new :name => "testing"
        catalog.add_resource(obj)
        bucket = obj.bucket
        
        assert_nothing_raised do
            file[:backup] = "testing"
        end
        assert_equal("testing", file[:backup], "backup value was reset")
        assert_equal(obj.bucket, file.bucket, "file's bucket was not set")
    end
    
    def test_pathbuilder
        dir = tempfile()
        Dir.mkdir(dir)
        file = File.join(dir, "file")
        File.open(file, "w") { |f| f.puts "" }
        obj = Puppet::Type.newfile :path => dir, :recurse => true, :mode => 0755
        catalog = mk_catalog obj
        transaction = Puppet::Transaction.new(catalog)
        
        assert_equal("/%s" % obj.ref, obj.path)
        
        list = transaction.eval_generate(obj)
        fileobj = catalog.resource(:file, file)
        assert(fileobj, "did not generate file object")
        assert_equal("/%s" % fileobj.ref, fileobj.path, "did not generate correct subfile path")
    end
    
    # Testing #403
    def test_removal_with_content_set
        path = tempfile()
        File.open(path, "w") { |f| f.puts "yay" }
        file = Puppet::Type.newfile(:name => path, :ensure => :absent, :content => "foo")
        
        assert_apply(file)
        assert(! FileTest.exists?(path), "File was not removed")
    end
    
    # Testing #438
    def test_creating_properties_conflict
        file = tempfile()
        first = tempfile()
        second = tempfile()
        params = [:content, :source, :target]
        params.each do |param|
            assert_nothing_raised("%s conflicted with ensure" % [param]) do
                Puppet::Type.newfile(:path => file, param => first, :ensure => :file)
            end
            params.each do |other|
                next if other == param
                assert_raise(Puppet::Error, "%s and %s did not conflict" % [param, other]) do
                    Puppet::Type.newfile(:path => file, other => first, param => second)
                end
            end
        end
    end

    # Testing #508
    if Process.uid == 0
    def test_files_replace_with_right_attrs
        source = tempfile()
        File.open(source, "w") { |f|
            f.puts "some text"
        }
        File.chmod(0755, source)
        user = nonrootuser
        group = nonrootgroup
        path = tempfile()
        good = {:uid => user.uid, :gid => group.gid, :mode => 0640}

        run = Proc.new do |obj, msg|
            assert_apply(obj)
            stat = File.stat(obj[:path])
            good.each do |should, sval|
                if should == :mode
                    current = filemode(obj[:path])
                else
                    current = stat.send(should)
                end
                assert_equal(sval, current,
                    "Attr %s was not correct %s" % [should, msg])
            end
        end

        file = Puppet::Type.newfile(:path => path, :owner => user.name,
            :group => group.name, :mode => 0640, :backup => false)
        {:source => source, :content => "some content"}.each do |attr, value|
            file[attr] = value
            # First create the file
            run.call(file, "upon creation with %s" % attr)

            # Now change something so that we replace the file
            case attr
            when :source
                    File.open(source, "w") { |f| f.puts "some different text" }
            when :content; file[:content] = "something completely different"
            else
                raise "invalid attr %s" % attr
            end
            
            # Run it again
            run.call(file, "after modification with %s" % attr)

            # Now remove the file and the attr
            file.delete(attr)
            File.unlink(path)
        end
    end
    end

    # Make sure we default to the "puppet" filebucket, rather than a string
    def test_backup_defaults_to_bucket
        path = tempfile
        file = Puppet::Type.newfile(:path => path, :content => 'some content')
        file.finish

        assert_instance_of(Puppet::Network::Client::Dipper, file.bucket,
            "did not default to a filebucket for backups")
    end

    # #567
    def test_missing_files_are_in_sync
        file = tempfile
        obj = Puppet::Type.newfile(:path => file, :mode => 0755)

        changes = obj.evaluate
        assert(changes.empty?, "Missing file with no ensure resulted in changes")
    end

    def test_root_dir_is_named_correctly
        obj = Puppet::Type.newfile(:path => '/', :mode => 0755)
        assert_equal("/", obj.title, "/ directory was changed to empty string")
    end

    # #1010 and #1037 -- write should fail if the written checksum does not
    # match the file we thought we were writing.
    def test_write_validates_checksum
        file = tempfile
        inst = Puppet::Type.newfile(:path => file, :content => "something")

        tmpfile = file + ".puppettmp"

        wh = mock 'writehandle', :print => nil
        rh = mock 'readhandle'
        rh.expects(:read).with(4096).times(2).returns("other").then.returns(nil)
        File.expects(:open).with { |*args| args[0] == tmpfile and args[1] != "r" }.yields(wh)
        File.expects(:open).with { |*args| args[0] == tmpfile and args[1] == "r" }.yields(rh)

        File.stubs(:rename)
        FileTest.stubs(:exist?).returns(true)
        FileTest.stubs(:file?).returns(true)

        inst.expects(:fail)
        inst.write("something", :whatever)
    end
end
