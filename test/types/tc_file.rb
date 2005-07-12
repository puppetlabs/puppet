if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'

# $Id$

class TestFile < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
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
            assert_nothing_raised() {
                system("rm -f %s" % path)
            }
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
        system("rm -f %s" % link)
    end

    def test_checksums
        types = %w{md5 md5lite timestamp ctime}
        files = %w{/tmp/sumtest}
        assert_nothing_raised() {
            Puppet::Storage.init
        #    Puppet::Storage.load
        }
        types.each { |type|
            files.each { |path|
                if Puppet[:debug]
                    Puppet.info "Testing %s on %s" % [type,path]
                end
                file = nil
                events = nil
                assert_nothing_raised() {
                    File.open(path,"w") { |of|
                        10.times { 
                            of.puts rand(100)
                        }
                    }
                }
                # okay, we now know that we have a file...
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
                assert_nothing_raised() {
                    system("rm -f %s" % path)
                }
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
        system("rm -rf #{path}")
    end
end
