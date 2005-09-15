if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $:.unshift "../../../../language/trunk/lib"
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'
require 'fileutils'
require 'puppettest'

# $Id$

class TestFile < TestPuppet
    include FileTesting
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def mkfile(hash)
        file = nil
        assert_nothing_raised {
            file = Puppet::Type::PFile.new(hash)
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
        begin
            initstorage
        rescue
            system("rm -rf %s" % Puppet[:checksumfile])
        end
        super
    end

    def teardown
        clearstorage
        Puppet::Storage.clear
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

        # we can really only test changing ownership if we're root
        if Process.uid == 0
            users.each { |uid, name|
                assert_nothing_raised() {
                    file[:owner] = name
                }
                changes = []
                assert_nothing_raised() {
                    changes << file.evaluate
                }
                assert(changes.length > 0)
                assert_nothing_raised() {
                    file.sync
                }
                assert_nothing_raised() {
                    file.evaluate
                }
                assert(file.insync?())
                assert_nothing_raised() {
                    file[:owner] = uid
                }
                assert_nothing_raised() {
                    file.evaluate
                }
                # make sure changing to number doesn't cause a sync
                assert(file.insync?())
            }

            fake.each { |uid, name|
                assert_raise(Puppet::Error) {
                    file[:owner] = name
                }
                assert_raise(Puppet::Error) {
                    file[:owner] = uid
                }
            }
        else
            uid, name = users.shift
            us = {}
            us[uid] = name
            users.each { |uid, name|
                # just make sure we don't try to manage users
                assert_nothing_raised() {
                    file.sync
                }
                assert_nothing_raised() {
                    file[:owner] = name
                }
                assert_nothing_raised() {
                    file.retrieve
                }
                assert(file.insync?())
                assert_nothing_raised() {
                    file.sync
                }
            }
        end
    end

    def test_group
        file = mktestfile()
        [%x{groups}.chomp.split(/ /), Process.groups].flatten.each { |group|
            assert_nothing_raised() {
                file[:group] = group
            }
            assert(file.state(:group))
            assert(file.state(:group).should)
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
            assert_nothing_raised() {
                file.delete(:group)
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
        file = mktestfile
        [0644,0755,0777,0641].each { |mode|
            assert_nothing_raised() {
                file[:mode] = mode
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
                comp = Puppet::Type::Component.new(
                    :name => "componentfile"
                )
                comp.push file
                trans = nil
                assert_nothing_raised() {
                    trans = comp.evaluate
                }

                if file.name !~ /nonexists/
                    sum = file.state(:checksum)
                    assert_equal(sum.is, sum.should)
                    assert(sum.insync?)
                end

                assert_nothing_raised() {
                    events = trans.evaluate.collect { |e| e.event }
                }
                # we don't want to kick off an event the first time we
                # come across a file
                assert(
                    ! events.include?(:file_modified)
                )
                assert_nothing_raised() {
                    File.open(path,"w") { |of|
                        of.puts rand(100)
                    }
                }
                Puppet::Type::PFile.clear
                Puppet::Type::Component.clear
                sleep 1

                # now recreate the file
                assert_nothing_raised() {
                    file = Puppet::Type::PFile.new(
                        :name => path,
                        :checksum => type
                    )
                }
                comp = Puppet::Type::Component.new(
                    :name => "componentfile"
                )
                comp.push file
                trans = nil
                assert_nothing_raised() {
                    trans = comp.evaluate
                }
                assert_nothing_raised() {
                    events = trans.evaluate.collect { |e| e.event }
                }

                sum = file.state(:checksum)

                # verify that we're actually getting notified when a file changes
                assert(
                    events.include?(:file_modified)
                )
                assert_nothing_raised() {
                    Puppet::Type::PFile.clear
                    Puppet::Type::Component.clear
                }
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
                file = Puppet::Type::PFile.new(
                    param => path,
                    :recurse => true,
                    :checksum => "md5"
                )
            }
            comp = Puppet::Type::Component.new(
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
                :create => true
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

        Puppet.err tmpdir()
        assert_nothing_raised {
            file = Puppet::Type::PFile.new(
                :name => tmpdir(),
                :check => :type
            )
        }

        assert_nothing_raised {
            file.evaluate
        }

        assert_equal("directory", file.state(:type).is)

        assert_nothing_raised {
            file = Puppet::Type::PFile.new(
                :name => "/etc/passwd",
                :check => :type
            )
        }

        assert_nothing_raised {
            file.evaluate
        }

        assert_equal("file", file.state(:type).is)

        assert_raise(Puppet::Error) {
            file[:type] = "directory"
        }

        assert(file.insync?)

        assert_raise(Puppet::Error) {
            file.sync
        }
    end
end
