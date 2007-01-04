#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'fileutils'
require 'puppettest'

class TestFile < Test::Unit::TestCase
    include PuppetTest::FileTesting
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def mkfile(hash)
        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(hash)
        }
        return file
    end

    def mktestfile
        # because luke's home directory is on nfs, it can't be used for testing
        # as root
        tmpfile = tempfile()
        File.open(tmpfile, "w") { |f| f.puts rand(100) }
        @@tmpfiles.push tmpfile
        mkfile(:name => tmpfile)
    end

    def setup
        super
        @file = Puppet::Type.type(:file)
        begin
            initstorage
        rescue
            system("rm -rf %s" % Puppet[:statefile])
        end
    end

    def teardown
        Puppet::Storage.clear
        system("rm -rf %s" % Puppet[:statefile])
        super
    end

    def initstorage
        Puppet::Storage.init
        Puppet::Storage.load
    end

    def clearstorage
        Puppet::Storage.store
        Puppet::Storage.clear
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
            assert(file.state(:group))
            assert(file.state(:group).should)
        }
    end

    if Puppet::SUIDManager.uid == 0
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

            comp = newcomp("createusertest", file)

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
            obj[:links] = :ignore

            # And then test 'group'
            group = nonrootgroup

            initgroup = File.stat(file).gid
            obj[:group] = group.name

            assert_events([:file_changed], obj)
            assert_equal(initgroup, File.stat(file).gid)
            assert_equal(group.gid, File.lstat(link).gid)
            File.chown(nil, initgroup, file)
            File.lchown(nil, initgroup, link)

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
                file.retrieve
                assert(file.insync?())
                assert_nothing_raised() {
                    file[:owner] = uid
                }
                assert_apply(file)
                file.retrieve
                # make sure changing to number doesn't cause a sync
                assert(file.insync?())
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
                assert_nothing_raised() {
                    file[:group] = group
                }
                assert(file.state(:group))
                assert(file.state(:group).should)
                assert_apply(file)
                file.retrieve
                assert(file.insync?())
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
            assert(file.insync?())
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
            assert(file.insync?())
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

            assert(file.insync?())

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

                file.retrieve

                if file.title !~ /nonexists/
                    sum = file.state(:checksum)
                    assert(sum.insync?, "file is not in sync")
                end

                events = assert_apply(file)

                assert(! events.include?(:file_changed),
                    "File incorrectly changed")
                assert_events([], file)

                # We have to sleep because the time resolution of the time-based
                # mechanisms is greater than one second
                sleep 1 if type =~ /time/

                assert_nothing_raised() {
                    File.open(path,File::CREAT|File::TRUNC|File::WRONLY) { |of|
                        of.puts "some more text, yo"
                    }
                }
                Puppet.type(:file).clear

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
                assert_nothing_raised do
                    file.state(:checksum).retrieve
                end
                assert(file.state(:checksum).insync?,
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

                # verify that we're actually getting notified when a file changes
                assert_nothing_raised() {
                    Puppet.type(:file).clear
                }

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
        
        Dir.mkdir(path)
        
        # Make sure we return nothing when there are no children
        ret = nil
        assert_nothing_raised() { ret = dir.localrecurse(true) }
        assert_equal([], ret, "empty dir returned children")
        
        # Now make a file and make sure we get it
        test = File.join(path, "file")
        File.open(test, "w") { |f| f.puts "yay" }
        assert_nothing_raised() { ret = dir.localrecurse(true) }
        fileobj = @file[test]
        assert(fileobj, "child object was not created")
        assert_equal([fileobj], ret, "child object was not returned")
        
        # check that the file lists us as a dependency
        assert_equal([[:file, dir.title]], fileobj[:require], "dependency was not set up")
        
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
        
        badobj = @file[bad]
        assert(badobj, "did not create bad object")
        assert_equal(:absent, badobj.should(:ensure), "ensure was not set to absent on bad object")
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
        [:localrecurse, :sourcerecurse, :linkrecurse].each do |m|
            dir.meta_def(m) do |recurse|
                if return_nil # for testing nil return, of course
                    return nil
                else
                    return [recurse]
                end
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
            
            children = nil

            assert_nothing_raised {
                children = dir.eval_generate
            }
            
            assert_equal([subdir], children.collect {|c| c.title },
                "Incorrect generated children")
            
            dir.class[subdir].remove

            File.open(tmpfile, "w") { |f| f.puts "yayness" }
            
            assert_nothing_raised {
                children = dir.eval_generate
            }

            assert_equal([subdir, tmpfile].sort, children.collect {|c| c.title }.sort,
                "Incorrect generated children")
            
            File.unlink(tmpfile)
            #system("rm -rf %s" % basedir)
            Puppet.type(:file).clear
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

        assert_equal("directory", file.state(:type).is)

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

        assert_equal("file", file.state(:type).is)

        file[:type] = "directory"

        assert_nothing_raised { file.retrieve }

        # The 'retrieve' method sets @should to @is, so they're never
        # out of sync.  It's a read-only class.
        assert(file.insync?)
    end

    def test_remove
        basedir = tempfile()
        subdir = File.join(basedir, "this")
        FileUtils.mkdir_p(subdir)

        dir = nil
        assert_nothing_raised {
            dir = Puppet.type(:file).create(
                :path => basedir,
                :recurse => true,
                :check => %w{owner mode group}
            )
        }

        assert_nothing_raised {
            dir.eval_generate
        }

        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:file)[subdir]
        }

        assert(obj, "Could not retrieve subdir object")

        assert_nothing_raised {
            obj.remove(true)
        }

        assert_nothing_raised {
            obj = Puppet.type(:file)[subdir]
        }

        assert_nil(obj, "Retrieved removed object")
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

        assert_nothing_raised {
            dirobj.eval_generate
        }

        assert_nothing_raised {
            file = dirobj.class[path]
        }

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

        assert(!obj.insync?, "Object is incorrectly in sync")

        assert_events([:file_created], obj)

        obj.retrieve

        assert(obj.insync?, "Object is not in sync")

        text = File.read(file)

        assert_equal(str, text, "Content did not copy correctly")

        newstr = "Another string, yo"

        obj[:content] = newstr

        assert(!obj.insync?, "Object is incorrectly in sync")

        assert_events([:file_changed], obj)

        text = File.read(file)

        assert_equal(newstr, text, "Content did not copy correctly")

        obj.retrieve
        assert(obj.insync?, "Object is not in sync")
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

        comp = newcomp("yay", file)
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

        file.retrieve

        assert_events([:file_created], file)
        file.retrieve
        assert_events([], file)
        assert_events([], file)
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

        assert(file.state(:group), "Group state failed")
    end

    def test_modecreation
        path = tempfile()
        file = Puppet.type(:file).create(
            :path => path,
            :ensure => "file",
            :mode => "0777"
        )
        assert_apply(file)
        assert_equal(0777, File.stat(path).mode & 007777)
        File.unlink(path)
        file[:ensure] = "directory"
        assert_apply(file)
        assert_equal(0777, File.stat(path).mode & 007777)
    end

    def test_followlinks
        basedir = tempfile()
        Dir.mkdir(basedir)
        file = File.join(basedir, "file")
        link = File.join(basedir, "link")

        File.open(file, "w", 0644) { |f| f.puts "yayness"; f.flush }
        File.symlink(file, link)

        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:file).create(
                :path => link,
                :mode => "755"
            )
        }
        obj.retrieve

        assert_events([], obj)

        # Assert that we default to not following links
        assert_equal("%o" % 0644, "%o" % (File.stat(file).mode & 007777))

        # Assert that we can manage the link directly, but modes still don't change
        obj[:links] = :manage
        assert_events([], obj)

        assert_equal("%o" % 0644, "%o" % (File.stat(file).mode & 007777))

        obj[:links] = :follow
        assert_events([:file_changed], obj)

        assert_equal("%o" % 0755, "%o" % (File.stat(file).mode & 007777))

        # Now verify that content and checksum don't update, either
        obj.delete(:mode)
        obj[:checksum] = "md5"
        obj[:links] = :ignore

        assert_events([], obj)
        File.open(file, "w") { |f| f.puts "more text" }
        assert_events([], obj)
        obj[:links] = :follow
        assert_events([], obj)
        File.open(file, "w") { |f| f.puts "even more text" }
        assert_events([:file_changed], obj)

        obj.delete(:checksum)
        obj[:content] = "this is some content"
        obj[:links] = :ignore

        assert_events([], obj)
        File.open(file, "w") { |f| f.puts "more text" }
        assert_events([], obj)
        obj[:links] = :follow
        assert_events([:file_changed], obj)
    end

    # If both 'ensure' and 'content' are used, make sure that all of the other
    # states are handled correctly.
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

    # Make sure we can create symlinks
    def test_symlinks
        path = tempfile()
        link = tempfile()

        File.open(path, "w") { |f| f.puts "yay" }

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :title => "somethingelse",
                :ensure => path,
                :path => link
            )
        }

        assert_events([:link_created], file)

        assert(FileTest.symlink?(link), "Link was not created")

        assert_equal(path, File.readlink(link), "Link was created incorrectly")

        # Make sure running it again works
        assert_events([], file)
        assert_events([], file)
        assert_events([], file)
    end
    
    def test_linkrecurse
        dest = tempfile()
        link = @file.create :path => tempfile(), :recurse => true, :ensure => dest
        
        ret = nil
        
        # Start with nothing, just to make sure we get nothing back
        assert_nothing_raised { ret = link.linkrecurse(true) }
        assert_nil(ret, "got a return when the dest doesn't exist")
        
        # then with a directory with only one file
        Dir.mkdir(dest)
        one = File.join(dest, "one")
        File.open(one, "w") { |f| f.puts "" }
        link[:ensure] = dest
        assert_nothing_raised { ret = link.linkrecurse(true) }
        
        assert_equal(:directory, link.should(:ensure), "ensure was not set to directory")
        assert_equal([File.join(link.title, "one")], ret.collect { |f| f.title },
            "Did not get linked file")
        oneobj = @file[File.join(link.title, "one")]
        assert_equal(one, oneobj.should(:target), "target was not set correctly")
        
        oneobj.remove
        File.unlink(one)
        
        # Then make sure we get multiple files
        returns = []
        5.times do |i|
            path = File.join(dest, i.to_s)
            returns << File.join(link.title, i.to_s)
            File.open(path, "w") { |f| f.puts "" }
        end
        assert_nothing_raised { ret = link.linkrecurse(true) }

        assert_equal(returns.sort, ret.collect { |f| f.title }.sort,
            "Did not get links back")
        
        returns.each do |path|
            obj = @file[path]
            assert(path, "did not get obj for %s" % path)
            sdest = File.join(dest, File.basename(path))
            assert_equal(sdest, obj.should(:target),
                "target was not set correctly for %s" % path)
        end
    end

    def test_simplerecursivelinking
        source = tempfile()
        path = tempfile()
        subdir = File.join(source, "subdir")
        file = File.join(subdir, "file")

        system("mkdir -p %s" % subdir)
        system("touch %s" % file)

        link = nil
        assert_nothing_raised {
            link = Puppet.type(:file).create(
                :ensure => source,
                :path => path,
                :recurse => true
            )
        }

        assert_apply(link)

        sublink = File.join(path, "subdir")
        linkpath = File.join(sublink, "file")
        assert(File.directory?(path), "dest is not a dir")
        assert(File.directory?(sublink), "subdest is not a dir")
        assert(File.symlink?(linkpath), "path is not a link")
        assert_equal(file, File.readlink(linkpath))

        assert_nil(@file[sublink], "objects were not removed")
        assert_events([], link)
    end

    def test_recursivelinking
        source = tempfile()
        dest = tempfile()

        files = []
        dirs = []

        # Make a bunch of files and dirs
        Dir.mkdir(source)
        Dir.chdir(source) do
            system("mkdir -p %s" % "some/path/of/dirs")
            system("mkdir -p %s" % "other/path/of/dirs")
            system("touch %s" % "file")
            system("touch %s" % "other/file")
            system("touch %s" % "some/path/of/file")
            system("touch %s" % "some/path/of/dirs/file")
            system("touch %s" % "other/path/of/file")

            files = %x{find . -type f}.chomp.split(/\n/)
            dirs = %x{find . -type d}.chomp.split(/\n/).reject{|d| d =~ /^\.+$/ }
        end

        link = nil
        assert_nothing_raised {
            link = Puppet.type(:file).create(
                :ensure => source,
                :path => dest,
                :recurse => true
            )
        }

        assert_apply(link)

        files.each do |f|
            f.sub!(/^\.#{File::SEPARATOR}/, '')
            path = File.join(dest, f)
            assert(FileTest.exists?(path), "Link %s was not created" % path)
            assert(FileTest.symlink?(path), "%s is not a link" % f)
            target = File.readlink(path)
            assert_equal(File.join(source, f), target)
        end

        dirs.each do |d|
            d.sub!(/^\.#{File::SEPARATOR}/, '')
            path = File.join(dest, d)
            assert(FileTest.exists?(path), "Dir %s was not created" % path)
            assert(FileTest.directory?(path), "%s is not a directory" % d)
        end
    end

    def test_localrelativelinks
        dir = tempfile()
        Dir.mkdir(dir)
        source = File.join(dir, "source")
        File.open(source, "w") { |f| f.puts "yay" }
        dest = File.join(dir, "link")

        link = nil
        assert_nothing_raised {
            link = Puppet.type(:file).create(
                :path => dest,
                :ensure => "source"
            )
        }

        assert_events([:link_created], link)
        assert(FileTest.symlink?(dest), "Did not create link")
        assert_equal("source", File.readlink(dest))
        assert_equal("yay\n", File.read(dest))
    end

    def test_recursivelinkingmissingtarget
        source = tempfile()
        dest = tempfile()

        objects = []
        objects << Puppet.type(:exec).create(
            :command => "mkdir %s; touch %s/file" % [source, source],
            :title => "yay",
            :path => ENV["PATH"]
        )
        objects << Puppet.type(:file).create(
            :ensure => source,
            :path => dest,
            :recurse => true,
            :require => objects[0]
        )

        assert_apply(*objects)

        link = File.join(dest, "file")
        assert(FileTest.symlink?(link), "Did not make link")
        assert_equal(File.join(source, "file"), File.readlink(link))
    end

    def test_backupmodes
        file = tempfile()
        newfile = tempfile()

        File.open(file, "w", 0411) { |f| f.puts "yayness" }

        obj = nil
        assert_nothing_raised {
            obj = Puppet::Type.type(:file).create(
                :path => file, :content => "rahness\n", :backup => ".puppet-bak"
            )
        }

        assert_apply(obj)

        backupfile = file + obj[:backup]
        @@tmpfiles << backupfile
        assert(FileTest.exists?(backupfile),
            "Backup file %s does not exist" % backupfile)

        assert_equal(0411, filemode(backupfile),
            "File mode is wrong for backupfile")

        bucket = "bucket"
        bpath = tempfile()
        Dir.mkdir(bpath)
        Puppet::Type.type(:filebucket).create(
            :title => bucket, :path => bpath
        )

        obj[:backup] = bucket
        obj[:content] = "New content"
        assert_apply(obj)

        bucketedpath = File.join(bpath, "18cc17fa3047fcc691fdf49c0a7f539a", "contents")

        assert_equal(0440, filemode(bucketedpath))
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

    def test_replacedirwithlink
        path = tempfile()
        link = tempfile()

        File.open(path, "w") { |f| f.puts "yay" }
        Dir.mkdir(link)
        File.open(File.join(link, "yay"), "w") do |f| f.puts "boo" end

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :ensure => path,
                :path => link,
                :backup => false
            )
        }

        # First run through without :force
        assert_events([], file)

        assert(FileTest.directory?(link), "Link replaced dir without force")

        assert_nothing_raised { file[:force] = true }

        assert_events([:link_created], file)

        assert(FileTest.symlink?(link), "Link was not created")

        assert_equal(path, File.readlink(link), "Link was created incorrectly")
    end

    def test_replace_links_with_files
        base = tempfile()

        Dir.mkdir(base)

        file = File.join(base, "file")
        link = File.join(base, "link")
        File.open(file, "w") { |f| f.puts "yayness" }
        File.symlink(file, link)

        obj = Puppet::Type.type(:file).create(
            :path => link,
            :ensure => "file"
        )

        assert_apply(obj)

        assert_equal("yayness\n", File.read(file),
            "Original file got changed")
        assert_equal("file", File.lstat(link).ftype, "File is still a link")
    end

    def test_no_erase_linkedto_files
        base = tempfile()

        Dir.mkdir(base)

        dirs = {}
        %w{other source target}.each do |d|
            dirs[d] = File.join(base, d)
            Dir.mkdir(dirs[d])
        end

        file = File.join(dirs["other"], "file")
        sourcefile = File.join(dirs["source"], "sourcefile")
        link = File.join(dirs["target"], "link")

        File.open(file, "w") { |f| f.puts "other" }
        File.open(sourcefile, "w") { |f| f.puts "source" }
        File.symlink(file, link)

        obj = Puppet::Type.type(:file).create(
            :path => dirs["target"],
            :ensure => "file",
            :source => dirs["source"],
            :recurse => true
        )


        trans = assert_events([:file_created, :file_created], obj)

        newfile = File.join(dirs["target"], "sourcefile")

        assert(File.exists?(newfile), "File did not get copied")

        assert_equal(File.read(sourcefile), File.read(newfile),
            "File did not get copied correctly.")

        assert_equal("other\n", File.read(file),
            "Original file got changed")
        assert_equal("file", File.lstat(link).ftype, "File is still a link")
    end

    def test_replace_links
        dest = tempfile()
        otherdest = tempfile()
        link = tempfile()

        File.open(dest, "w") { |f| f.puts "boo" }
        File.open(otherdest, "w") { |f| f.puts "yay" }

        obj = Puppet::Type.type(:file).create(
            :path => link,
            :ensure => otherdest
        )


        assert_apply(obj)

        assert_equal(otherdest, File.readlink(link), "Link did not get created")

        obj[:ensure] = dest

        assert_apply(obj)

        assert_equal(dest, File.readlink(link), "Link did not get changed")
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

        file.retrieve
        assert(! file.insync?, "File incorrectly in sync")

        # Now make a file
        File.open(path, "w") { |f| f.puts "yay" }

        file.retrieve
        assert(file.insync?, "File not in sync")

        # Now make a directory
        File.unlink(path)
        Dir.mkdir(path)

        file.retrieve
        assert(file.insync?, "Directory not considered 'present'")

        Dir.rmdir(path)

        # Now make a link
        file[:links] = :manage

        otherfile = tempfile()
        File.symlink(otherfile, path)

        file.retrieve
        assert(file.insync?, "Symlink not considered 'present'")
        File.unlink(path)

        # Now set some content, and make sure it works
        file[:content] = "yayness"

        assert_apply(file)

        assert_equal("yayness", File.read(path), "Content did not get set correctly")
    end

    # Make sure unmanaged files are be purged.
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

        lfobj = Puppet::Type.newfile(:title => "localfile", :path => localfile, :content => "rahtest")
        

        destobj = Puppet::Type.newfile(:title => "destdir", :path => destdir,
                                    :source => sourcedir,
                                    :recurse => true)

        comp = newcomp(lfobj, destobj)
        assert_apply(comp)

        assert(FileTest.exists?(dsourcefile), "File did not get copied")
        assert(FileTest.exists?(localfile), "File did not get created")
        assert(FileTest.exists?(purgee), "File got prematurely purged")

        assert_nothing_raised { destobj[:purge] = true }
        assert_apply(comp)

        assert(FileTest.exists?(dsourcefile), "File got purged")
        assert(FileTest.exists?(localfile), "File got purged")
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
            comp = newcomp(user, group, home)
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
            assert_equal(file, Puppet::Type.type(:file)["/my/file/for/testing"])
            Puppet::Type.type(:file).clear
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
        obj = Puppet::Type.newfile :path => link, :ensure => :link,
            :target => file, :recurse => false, :backup => "main"

        assert_apply(obj)

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
                        if obj.state(:target)
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

                    state = obj.state(:ensure)

                    state.retrieve
                    unless state.insync?
                        assert_nothing_raised do
                            state.sync
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
        dipper = Puppet::Server::FileBucket.new(
            :Path => bpath
        )
        assert(dipper, "did not receive bucket client")
        file = Puppet::Type.newfile :path => dest, :source => source, :recurse => true, :backup => "rtest"
        
        assert_apply(file)
        dfiles.each do |f|
            assert(FileTest.exists?(f), "destfile %s was not created" % f)
        end
        
        # Now modify the source files to make sure things get backed up correctly
        [s1, s2].each { |sf| File.open(sf, "w") { |f|
            f.puts "boo: %s" % File.basename(sf)
        } }
        
        assert_apply(file)
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
        
        assert_equal("/%s" % obj.ref, obj.path)
        
        list = obj.eval_generate
        fileobj = obj.class[file]
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
end

# $Id$
