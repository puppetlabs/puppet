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
                comp = Puppet.type(:component).create(
                    :name => "checksum %s" % type
                )
                comp.push file
                trans = nil

                file.retrieve

                if file.title !~ /nonexists/
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
        [true, "true", "inf", 50].each do |value|
            assert_nothing_raised {
                dir = Puppet.type(:file).create(
                    :path => basedir,
                    :recurse => value,
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
            #system("rm -rf %s" % basedir)
            Puppet.type(:file).clear
        end
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

        assert_equal("file=%s" % file.title, file.path)
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
                :ensure => path,
                :path => link
            )
        }

        assert_events([:link_created], file)

        assert(FileTest.symlink?(link), "Link was not created")

        assert_equal(path, File.readlink(link), "Link was created incorrectly")

        # Make sure running it again works
        assert_events([], file)
    end

    def test_simplerecursivelinking
        source = tempfile()
        dest = tempfile()
        subdir = File.join(source, "subdir")
        file = File.join(subdir, "file")

        system("mkdir -p %s" % subdir)
        system("touch %s" % file)

        link = nil
        assert_nothing_raised {
            link = Puppet.type(:file).create(
                :ensure => source,
                :path => dest,
                :recurse => true
            )
        }

        assert_apply(link)

        subdest = File.join(dest, "subdir")
        linkpath = File.join(subdest, "file")
        assert(File.directory?(dest), "dest is not a dir")
        assert(File.directory?(subdest), "subdest is not a dir")
        assert(File.symlink?(linkpath), "path is not a link")
        assert_equal(file, File.readlink(linkpath))

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
            :path => ENV["PATH"]
        )
        objects << Puppet.type(:file).create(
            :ensure => source,
            :path => dest,
            :recurse => true
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
                :path => file, :content => "rahness\n"
            )
        }

#        user = group = nil
#        if Process.uid == 0
#            user = nonrootuser
#            group = nonrootgroup
#            obj[:owner] = user.name
#            obj[:group] = group.name
#            File.chown(user.uid, group.gid, file)
#        end

        assert_apply(obj)

        backupfile = file + obj[:backup]
        @@tmpfiles << backupfile
        assert(FileTest.exists?(backupfile),
            "Backup file %s does not exist" % backupfile)

        assert_equal(0411, filemode(backupfile),
            "File mode is wrong for backupfile")

#        if Process.uid == 0
#            assert_equal(user.uid, File.stat(backupfile).uid)
#            assert_equal(group.gid, File.stat(backupfile).gid)
#        end

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
end

# $Id$
