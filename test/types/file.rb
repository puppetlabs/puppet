if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'test/unit'
require 'fileutils'
require 'puppettest'

class TestFile < Test::Unit::TestCase
	include FileTesting
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

    if Process.uid == 0
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

            user = nonrootuser()

            obj = nil
            assert_nothing_raised {
                obj = Puppet.type(:file).create(
                    :name => link,
                    :owner => user.name
                )
            }
            obj.retrieve

            assert_events([:file_changed], obj)

            assert_equal(0, File.stat(file).uid)

            obj[:links] = :follow
            assert_events([:file_changed], obj)
            assert_equal(user.uid, File.stat(file).uid)
            File.chown(0, nil, file)

            obj[:links] = :copy
            assert_events([:file_changed], obj)
            assert_equal(user.uid, File.stat(file).uid)

            obj.delete(:owner)
            obj[:links] = :skip

            group = nonrootgroup

            initgroup = File.stat(file).gid
            obj[:group] = group.name

            assert_events([:file_changed], obj)

            assert_equal(initgroup, File.stat(file).gid)

            obj[:links] = :follow
            assert_events([:file_changed], obj)
            assert_equal(group.gid, File.stat(file).gid)
            File.chown(nil, initgroup, file)

            obj[:links] = :copy
            assert_events([:file_changed], obj)
            assert_equal(group.gid, File.stat(file).gid)
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
        File.chmod(0775, file.name)
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
                comp = Puppet.type(:component).create(
                    :name => "checksum %s" % type
                )
                comp.push file
                trans = nil

                file.retrieve

                if file.name !~ /nonexists/
                    sum = file.state(:checksum)
                    assert_equal(sum.is, sum.should)
                    assert(sum.insync?)
                end

                events = assert_apply(comp)

                assert(! events.include?(:file_changed),
                    "File incorrectly changed")
                assert_events([], comp)

                # We have to sleep because the time resolution of the time-based
                # mechanisms is greater than one second
                sleep 1

                assert_nothing_raised() {
                    File.open(path,File::CREAT|File::TRUNC|File::WRONLY) { |of|
                        of.puts "some more text, yo"
                    }
                }
                Puppet.type(:file).clear
                Puppet.type(:component).clear

                # now recreate the file
                assert_nothing_raised() {
                    file = Puppet.type(:file).create(
                        :name => path,
                        :checksum => type
                    )
                }
                comp = Puppet.type(:component).create(
                    :name => "checksum, take 2, %s" % type
                )
                comp.push file
                trans = nil

                # If the file was missing, it should not generate an event
                # when it gets created.
                #if path =~ /nonexists/
                #    assert_events([], comp)
                #else
                    assert_events([:file_changed], comp)
                #end
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
                #assert_apply(comp)
                assert_events([:file_changed], comp)

                # verify that we're actually getting notified when a file changes
                assert_nothing_raised() {
                    Puppet.type(:file).clear
                    Puppet.type(:component).clear
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

    def test_recursion
        basedir = tempfile()
        subdir = File.join(basedir, "this", "is", "sub", "dir")
        tmpfile = File.join(subdir,"testing")
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
            dir.evaluate
        }

        subobj = nil
        assert_nothing_raised {
            subobj = Puppet.type(:file)[subdir]
        }

        assert(subobj, "Could not retrieve %s object" % subdir)

        File.open(tmpfile, "w") { |f| f.puts "yayness" }

        dir.evaluate

        file = nil
        assert_nothing_raised {
            file = Puppet.type(:file)[tmpfile]
        }

        assert(file, "Could not retrieve %s object" % tmpfile)

    end

=begin
    def test_ignore

    end
=end

    # XXX disabled until i change how dependencies work
    def disabled_test_recursionwithcreation
        path = "/tmp/this/directory/structure/does/not/exist"
        @@tmpfiles.push "/tmp/this"

        file = nil
        assert_nothing_raised {
            file = mkfile(
                :name => path,
                :recurse => true,
                :ensure => "file"
            )
        }

        trans = nil
        comp = newcomp("recursewithfiles", file) 
        assert_nothing_raised {
            trans = comp.evaluate
        }

        events = nil
        assert_nothing_raised {
            events = trans.evaluate.collect { |e| e.event.to_s }
        }

        puts "events are %s" % events.join(",  ")
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
            dir.retrieve
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

        path = File.join(dir, "and", "a", "sub", "dir")

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
            dirobj.evaluate
        }

        assert_nothing_raised {
            file = dirobj.class[path]
        }

        assert(file, "Could not retrieve file object")

        assert_equal("file=%s" % file.name, file.path)
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
        comp = newcomp(baseobj, subobj)
        comp.finalize

        assert(subobj.requires?(baseobj), "File did not require basedir")
        assert(!subobj.requires?(subobj), "File required itself")
        assert_events([:directory_created, :file_created], comp)
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
                :name => "fileness",
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
                :name => link,
                :mode => "755"
            )
        }
        obj.retrieve

        assert_events([], obj)

        # Assert that we default to not following links
        assert_equal("%o" % 0644, "%o" % (File.stat(file).mode & 007777))

        obj[:links] = :follow
        assert_events([:file_changed], obj)

        assert_equal("%o" % 0755, "%o" % (File.stat(file).mode & 007777))

        File.chmod(0644, file)
        obj[:links] = :copy
        assert_events([:file_changed], obj)

        assert_equal("%o" % 0755, "%o" % (File.stat(file).mode & 007777))

        # Now verify that content and checksum don't update, either
        obj.delete(:mode)
        obj[:checksum] = "md5"
        obj[:links] = :skip

        assert_events([], obj)
        File.open(file, "w") { |f| f.puts "more text" }
        assert_events([], obj)
        obj[:links] = :follow
        assert_events([], obj)
        File.open(file, "w") { |f| f.puts "even more text" }
        assert_events([:file_changed], obj)

        obj.delete(:checksum)
        obj[:content] = "this is some content"
        obj[:links] = :skip

        assert_events([], obj)
        File.open(file, "w") { |f| f.puts "more text" }
        assert_events([], obj)
        obj[:links] = :follow
        assert_events([:file_changed], obj)
    end
end

# $Id$
