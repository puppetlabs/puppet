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
            file = Puppet.type(:file).create(hash)
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
            Puppet::Type.type(:file).create :path => "/some/file", :group => ""
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
                file = Puppet.type(:file).create(
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
                obj = Puppet.type(:file).create(
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
                file = Puppet.type(:file).create(
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
                file = Puppet.type(:file).create(
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

    def test_checksums
        types = %w{md5 md5lite timestamp time}
        exists = "/tmp/sumtest-exists"
        nonexists = "/tmp/sumtest-nonexists"

        @@tmpfiles << exists
        @@tmpfiles << nonexists

        # try it both with files that exist and ones that don't
        files = [exists, nonexists]
        initstorage
        File.open(exists,File::CREAT|File::TRUNC|File::WRONLY) { |of|
            of.puts "initial text"
        }
        types.each { |type|
            files.each { |path|
                if Puppet[:debug]
                    Puppet.warning "Testing %s on %s" % [type,path]
                end
                file = nil
                events = nil
                # okay, we now know that we have a file...
                assert_nothing_raised() {
                    file = Puppet.type(:file).create(
                        :name => path,
                        :ensure => "file",
                        :checksum => type
                    )
                }
                trans = nil

                currentvalues = file.retrieve

                if file.title !~ /nonexists/
                    sum = file.property(:checksum)
                    assert(sum.insync?(currentvalues[sum]), "file is not in sync")
                end

                events = assert_apply(file)

                assert(events)

                assert(! events.include?(:file_changed), "File incorrectly changed")
                assert_events([], file)

                # We have to sleep because the time resolution of the time-based
                # mechanisms is greater than one second
                sleep 1 if type =~ /time/

                assert_nothing_raised() {
                    File.open(path,File::CREAT|File::TRUNC|File::WRONLY) { |of|
                        of.puts "some more text, yo"
                    }
                }

                # now recreate the file
                assert_nothing_raised() {
                    file = Puppet.type(:file).create(
                        :name => path,
                        :checksum => type
                    )
                }
                trans = nil

                assert_events([:file_changed], file)

                # Run it a few times to make sure we aren't getting
                # spurious changes.
                sum = nil
                assert_nothing_raised do
                    sum = file.property(:checksum).retrieve
                end
                assert(file.property(:checksum).insync?(sum),
                    "checksum is not in sync")

                sleep 1.1 if type =~ /time/
                assert_nothing_raised() {
                    File.unlink(path)
                    File.open(path,File::CREAT|File::TRUNC|File::WRONLY) { |of|
                        # We have to put a certain amount of text in here or
                        # the md5-lite test fails
                        2.times {
                            of.puts rand(100)
                        }
                        of.flush
                    }
                }
                assert_events([:file_changed], file)

                if path =~ /nonexists/
                    File.unlink(path)
                end
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
                file = Puppet.type(:file).create(
                    param => path,
                    :recurse => true,
                    :checksum => "md5"
                )
            }
            comp = Puppet.type(:component).create(
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
    
    def test_localrecurse
        # Create a test directory
        path = tempfile()
        dir = @file.create :path => path, :mode => 0755, :recurse => true
        catalog = mk_catalog(dir)
        
        Dir.mkdir(path)
        
        # Make sure we return nothing when there are no children
        ret = nil
        assert_nothing_raised() { ret = dir.localrecurse(true) }
        assert_equal([], ret, "empty dir returned children")
        
        # Now make a file and make sure we get it
        test = File.join(path, "file")
        File.open(test, "w") { |f| f.puts "yay" }
        assert_nothing_raised() { ret = dir.localrecurse(true) }
        fileobj = catalog.resource(:file, test)
        assert(fileobj, "child object was not created")
        assert_equal([fileobj], ret, "child object was not returned")
        
        # And that it inherited our recurse setting
        assert_equal(true, fileobj[:recurse], "file did not inherit recurse")
        
        # Make sure it's not returned again
        assert_nothing_raised() { ret = dir.localrecurse(true) }
        assert_equal([], ret, "child object was returned twice")
        
        # Now just for completion, make sure we will return many files
        files = []
        10.times do |i|
            f = File.join(path, i.to_s)
            files << f
            File.open(f, "w") do |o| o.puts "" end
        end
        assert_nothing_raised() { ret = dir.localrecurse(true) }
        assert_equal(files.sort, ret.collect { |f| f.title }.sort,
            "child object was returned twice")
        
        # Clean everything up and start over
        files << test
        files.each do |f| File.unlink(f) end
        
        # Now make sure we correctly ignore things
        dir[:ignore] = "*.out"
        bad = File.join(path, "test.out")
        good = File.join(path, "yayness")
        [good, bad].each do |f|
            File.open(f, "w") { |o| o.puts "" }
        end
        
        assert_nothing_raised() { ret = dir.localrecurse(true) }
        assert_equal([good], ret.collect { |f| f.title }, "ignore failed")
        
        # Now make sure purging works
        dir[:purge] = true
        dir[:ignore] = "svn"
        
        assert_nothing_raised() { ret = dir.localrecurse(true) }
        assert_equal([bad], ret.collect { |f| f.title }, "purge failed")
        
        badobj = catalog.resource(:file, bad)
        assert(badobj, "did not create bad object")
    end
    
    def test_recurse
        basedir = tempfile()
        FileUtils.mkdir_p(basedir)
        
        # Create our file
        dir = nil
        assert_nothing_raised {
            dir = Puppet.type(:file).create(
                :path => basedir,
                :check => %w{owner mode group}
            )
        }
        
        return_nil = false
        
        # and monkey-patch it
        [:localrecurse, :linkrecurse].each do |m|
            dir.meta_def(m) do |recurse|
                if return_nil # for testing nil return, of course
                    return nil
                else
                    return [recurse]
                end
            end
        end

        # We have to special-case this, because it returns a list of
        # found files.
        dir.meta_def(:sourcerecurse) do |recurse|
            if return_nil # for testing nil return, of course
                return nil
            else
                return [recurse], []
            end
        end
        
        # First try it with recurse set to false
        dir[:recurse] = false
        assert_nothing_raised do
            assert_nil(dir.recurse)
        end
        
        # Now try it with the different valid positive values
        [true, "true", "inf", 50].each do |value|
            assert_nothing_raised { dir[:recurse] = value}
            
            # Now make sure the methods are called appropriately
            ret = nil
            assert_nothing_raised do
                ret = dir.recurse
            end
            
            # We should only call the localrecurse method, so make sure
            # that's the case
            if value == 50
                # Make sure our counter got decremented
                assert_equal([49], ret, "did not call localrecurse")
            else
                assert_equal([true], ret, "did not call localrecurse")
            end
        end
        
        # Make sure it doesn't recurse when we've set recurse to false
        [false, "false"].each do |value|
            assert_nothing_raised { dir[:recurse] = value }
            
            ret = nil
            assert_nothing_raised() { ret = dir.recurse }
            assert_nil(ret)
        end
        dir[:recurse] = true
        
        # Now add a target, so we do the linking thing
        dir[:target] = tempfile()
        ret = nil
        assert_nothing_raised { ret = dir.recurse }
        assert_equal([true, true], ret, "did not call linkrecurse")
        
        # And add a source, and make sure we call that
        dir[:source] = tempfile()
        assert_nothing_raised { ret = dir.recurse }
        assert_equal([true, true, true], ret, "did not call linkrecurse")
        
        # Lastly, make sure we correctly handle returning nil
        return_nil = true
        assert_nothing_raised { ret = dir.recurse }
    end
    
    def test_recurse?
        file = Puppet::Type.type(:file).create :path => tempfile
        
        # Make sure we default to false
        assert(! file.recurse?, "Recurse defaulted to true")
        
        [true, "true", 10, "inf"].each do |value|
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
                dir = Puppet.type(:file).create(
                    :path => basedir,
                    :recurse => value,
                    :check => %w{owner mode group}
                )
            }
            config = mk_catalog dir
            
            children = nil

            assert_nothing_raised {
                children = dir.eval_generate
            }
            
            assert_equal([subdir], children.collect {|c| c.title },
                "Incorrect generated children")
            
            # Remove our subdir resource, 
            subdir_resource = config.resource(:file, subdir)
            config.remove_resource(subdir_resource)

            # Create the test file
            File.open(tmpfile, "w") { |f| f.puts "yayness" }
            
            assert_nothing_raised {
                children = dir.eval_generate
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
            file = Puppet.type(:file).create(
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
            file = Puppet.type(:file).create(
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
            dirobj = Puppet.type(:file).create(
                :path => dir,
                :recurse => true,
                :check => %w{mode owner group}
            )
        }
        catalog = mk_catalog dirobj

        assert_nothing_raised {
            dirobj.eval_generate
        }

        file = catalog.resource(:file, path)

        assert(file, "Could not retrieve file object")

        assert_equal("/%s" % file.ref, file.path)
    end

    def test_autorequire
        basedir = tempfile()
        subfile = File.join(basedir, "subfile")

        baseobj = Puppet.type(:file).create(
            :name => basedir,
            :ensure => "directory"
        )

        subobj = Puppet.type(:file).create(
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

    def test_content
        file = tempfile()
        str = "This is some content"

        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:file).create(
                :name => file,
                :content => str
            )
        }

        assert(!obj.insync?(obj.retrieve), "Object is incorrectly in sync")

        assert_events([:file_created], obj)

        currentvalues = obj.retrieve

        assert(obj.insync?(currentvalues), "Object is not in sync")

        text = File.read(file)

        assert_equal(str, text, "Content did not copy correctly")

        newstr = "Another string, yo"

        obj[:content] = newstr

        assert(!obj.insync?(obj.retrieve), "Object is incorrectly in sync")

        assert_events([:file_changed], obj)

        text = File.read(file)

        assert_equal(newstr, text, "Content did not copy correctly")

        currentvalues = obj.retrieve
        assert(obj.insync?(currentvalues), "Object is not in sync")
    end

    # Unfortunately, I know this fails
    def disabled_test_recursivemkdir
        path = tempfile()
        subpath = File.join(path, "this", "is", "a", "dir")
        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
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
            file = Puppet.type(:file).create(
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
            file = Puppet.type(:file).create(
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

    # Make sure that content gets used before ensure
    def test_contentbeatsensure
        dest = tempfile()

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :name => dest,
                :ensure => "file",
                :content => "this is some content, yo"
            )
        }

        currentvalues = file.retrieve

        assert_events([:file_created], file)
        file.retrieve
        assert_events([], file)
        assert_events([], file)
    end

    # Make sure that content gets used before ensure
    def test_deletion_beats_source
        dest = tempfile()
        source = tempfile()
        File.open(source, "w") { |f| f.puts "yay" }

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :name => dest,
                :ensure => :absent,
                :source => source
            )
        }

        file.retrieve

        assert_events([], file)
        assert(! FileTest.exists?(dest), "file was copied during deletion")

        # Now create the dest, and make sure it gets deleted
        File.open(dest, "w") { |f| f.puts "boo" }
        assert_events([:file_removed], file)
        assert(! FileTest.exists?(dest), "file was not deleted during deletion")
    end

    def test_nameandpath
        path = tempfile()

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
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
            file = Puppet.type(:file).create(
                :path => tempfile(),
                :group => "fakegroup"
            )
        }

        assert(file.property(:group), "Group property failed")
    end

    def test_modecreation
        path = tempfile()
        file = Puppet.type(:file).create(
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
            file = Puppet.type(:file).create(
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

        obj = Puppet::Type.type(:file).create(
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
        bucket = Puppet::Type.type(:filebucket).create(:title => name, :path => bpath)
        catalog.add_resource(bucket)

        obj[:backup] = name
        obj[:content] = "New content"
        catalog.finalize
        catalog.apply

        md5 = "18cc17fa3047fcc691fdf49c0a7f539a"
        dir, file, pathfile = Puppet::Network::Handler.filebucket.paths(bpath, md5)

        assert_equal(0440, filemode(file))
    end

    def test_largefilechanges
        source = tempfile()
        dest = tempfile()

        # Now make a large file
        File.open(source, "w") { |f|
            500.times { |i| f.puts "line %s" % i }
        }

        obj = Puppet::Type.type(:file).create(
            :title => dest, :source => source
        )

        assert_events([:file_created], obj)

        File.open(source, File::APPEND|File::WRONLY) { |f| f.puts "another line" }

        assert_events([:file_changed], obj)

        # Now modify the dest file
        File.open(dest, File::APPEND|File::WRONLY) { |f| f.puts "one more line" }

        assert_events([:file_changed, :file_changed], obj)

    end

    def test_replacefilewithlink
        path = tempfile()
        link = tempfile()

        File.open(path, "w") { |f| f.puts "yay" }
        File.open(link, "w") { |f| f.puts "a file" }

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
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
        obj = Puppet::Type.type(:file).create(
            :path => dest,
            :source => source
        )
        assert(obj, "Did not create file")

        assert_apply(obj)

        assert(FileTest.exists?(dest), "File did not get created")
    end

    def test_present_matches_anything
        path = tempfile()

        file = Puppet::Type.newfile(:path => path, :ensure => :present)

        currentvalues = file.retrieve
        assert(! file.insync?(currentvalues), "File incorrectly in sync")

        # Now make a file
        File.open(path, "w") { |f| f.puts "yay" }

        currentvalues = file.retrieve
        assert(file.insync?(currentvalues), "File not in sync")

        # Now make a directory
        File.unlink(path)
        Dir.mkdir(path)

        currentvalues = file.retrieve
        assert(file.insync?(currentvalues), "Directory not considered 'present'")

        Dir.rmdir(path)

        # Now make a link
        file[:links] = :manage

        otherfile = tempfile()
        File.symlink(otherfile, path)

        currentvalues = file.retrieve
        assert(file.insync?(currentvalues), "Symlink not considered 'present'")
        File.unlink(path)

        # Now set some content, and make sure it works
        file[:content] = "yayness"

        assert_apply(file)

        assert_equal("yayness", File.read(path), "Content did not get set correctly")
    end

    # Make sure unmanaged files are purged.
    def test_purge
        sourcedir = tempfile()
        destdir = tempfile()
        Dir.mkdir(sourcedir)
        Dir.mkdir(destdir)
        sourcefile = File.join(sourcedir, "sourcefile")
        dsourcefile = File.join(destdir, "sourcefile")
        localfile = File.join(destdir, "localfile")
        purgee = File.join(destdir, "to_be_purged")
        File.open(sourcefile, "w") { |f| f.puts "funtest" }
        # this file should get removed
        File.open(purgee, "w") { |f| f.puts "footest" }

        lfobj = Puppet::Type.newfile(
            :title => "localfile",
            :path => localfile,
            :content => "rahtest",
            :ensure => :file,
            :backup => false
        )

        destobj = Puppet::Type.newfile(:title => "destdir", :path => destdir,
                                    :source => sourcedir,
                                    :backup => false,
                                    :recurse => true)

        config = mk_catalog(lfobj, destobj)
        config.apply

        assert(FileTest.exists?(dsourcefile), "File did not get copied")
        assert(FileTest.exists?(localfile), "Local file did not get created")
        assert(FileTest.exists?(purgee), "Purge target got prematurely purged")

        assert_nothing_raised { destobj[:purge] = true }
        config.apply

        assert(FileTest.exists?(localfile), "Local file got purged")
        assert(FileTest.exists?(dsourcefile), "Source file got purged")
        assert(! FileTest.exists?(purgee), "File did not get purged")
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
            user = Puppet.type(:user).create(
                :name => "pptestu",
                :home => file,
                :gid => "pptestg"
            )
            home = Puppet.type(:file).create(
                :path => file,
                :owner => "pptestu",
                :group => "pptestg",
                :ensure => "directory"
            )
            group = Puppet.type(:group).create(
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

        bucket = Puppet::Type.newfilebucket :name => "main"
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

        bucket = Puppet::Type.newfilebucket :name => "main", :path => tempfile()

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
    
    # #365 -- make sure generated files also use filebuckets.
    def test_recursive_filebuckets
        source = tempfile()
        dest = tempfile()
        s1 = File.join(source, "1")
        sdir = File.join(source, "dir")
        s2 = File.join(sdir, "2")
        Dir.mkdir(source)
        Dir.mkdir(sdir)
        [s1, s2].each { |file| File.open(file, "w") { |f| f.puts "yay: %s" % File.basename(file) } }
        
        sums = {}
        [s1, s2].each do |f|
            sums[File.basename(f)] = Digest::MD5.hexdigest(File.read(f))
        end
        
        dfiles = [File.join(dest, "1"), File.join(dest, "dir", "2")]
        
        bpath = tempfile
        bucket = Puppet::Type.type(:filebucket).create :name => "rtest", :path => bpath
        dipper = bucket.bucket
        dipper = Puppet::Network::Handler.filebucket.new(
            :Path => bpath
        )
        assert(dipper, "did not receive bucket client")
        file = Puppet::Type.newfile :path => dest, :source => source, :recurse => true, :backup => "rtest"

        catalog = mk_catalog(bucket, file)
        
        catalog.apply

        dfiles.each do |f|
            assert(FileTest.exists?(f), "destfile %s was not created" % f)
        end
        
        # Now modify the source files to make sure things get backed up correctly
        [s1, s2].each { |sf| File.open(sf, "w") { |f|
            f.puts "boo: %s" % File.basename(sf)
        } }
        
        catalog.apply
        dfiles.each do |f|
            assert_equal("boo: %s\n" % File.basename(f), File.read(f),
                "file was not copied correctly")
        end
        
        # Make sure we didn't just copy the files over to backup locations
        dfiles.each do |f|
            assert(! FileTest.exists?(f + "rtest"),
            "file %s was copied for backup instead of bucketed" % File.basename(f))
        end
        
        # Now make sure we can get the source sums from the bucket
        sums.each do |f, sum|
            result = nil
            assert_nothing_raised do
                result = dipper.getfile(sum)
            end
            assert(result, "file %s was not backed to filebucket" % f)
            assert_equal("yay: %s\n" % f, result, "file backup was not correct")
        end
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
        obj = Puppet::Type.type(:filebucket).create :name => "testing"
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
        
        assert_equal("/%s" % obj.ref, obj.path)
        
        list = obj.eval_generate
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
            when :source:
                    File.open(source, "w") { |f| f.puts "some different text" }
            when :content: file[:content] = "something completely different"
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

    # #505
    def test_numeric_recurse
        dir = tempfile()
        subdir = File.join(dir, "subdir")
        other = File.join(subdir, "deeper")
        file = File.join(other, "file")
        [dir, subdir, other].each { |d| Dir.mkdir(d) }
        File.open(file, "w") { |f| f.puts "yay" }
        File.chmod(0644, file)
        obj = Puppet::Type.newfile(:path => dir, :mode => 0750, :recurse => "2")
        catalog = mk_catalog(obj)

        children = nil
        assert_nothing_raised("Failure when recursing") do
            children = obj.eval_generate
        end
        assert(catalog.resource(:file, subdir), "did not create subdir object")
        children.each do |c|
            assert_nothing_raised("Failure when recursing on %s" % c) do
                c.catalog = catalog
                others = c.eval_generate
            end
        end
        oobj = catalog.resource(:file, other)
        assert(oobj, "did not create other object")

        assert_nothing_raised do
            assert_nil(oobj.eval_generate, "recursed too far")
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

    # #515 - make sure 'ensure' other than "link" is deleted during recursion
    def test_ensure_deleted_during_recursion
        dir = tempfile()
        Dir.mkdir(dir)
        file = File.join(dir, "file")
        File.open(file, "w") { |f| f.puts "asdfasdf" }

        obj = Puppet::Type.newfile(:path => dir, :ensure => :directory,
            :recurse => true)

        catalog = mk_catalog(obj)
        children = nil
        assert_nothing_raised do
            children = obj.eval_generate
        end
        fobj = catalog.resource(:file, file)
        assert(fobj, "did not create file object")
        assert(fobj.should(:ensure) != :directory, "ensure was passed to child")
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
        rh.expects(:read).with(512).times(2).returns("other").then.returns(nil)
        File.expects(:open).with { |*args| args[0] == tmpfile and args[1] != "r" }.yields(wh)
        File.expects(:open).with { |*args| args[0] == tmpfile and args[1] == "r" }.yields(rh)

        File.stubs(:rename)
        FileTest.stubs(:exist?).returns(true)
        FileTest.stubs(:file?).returns(true)

        inst.expects(:fail)
        inst.write("something", :whatever)
    end
end
