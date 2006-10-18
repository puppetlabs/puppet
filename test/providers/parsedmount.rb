#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/fileparsing'
require 'puppet'
require 'facter'

class TestParsedMounts < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::FileParsing

    def setup
        super
        @provider = Puppet.type(:mount).provider(:parsed)

        @oldfiletype = @provider.filetype
    end

    def teardown
        Puppet::FileType.filetype(:ram).clear
        @provider.filetype = @oldfiletype
        super
    end

    def mkmountargs
        mount = nil

        if defined? @pcount
            @pcount += 1
        else
            @pcount = 1
        end
        args = {
            :path => "/fspuppet%s" % @pcount,
            :device => "/dev/dsk%s" % @pcount,
        }

        @provider.fields.each do |field|
            unless args.include? field
                args[field] = "fake%s" % @pcount
            end
        end

        return args
    end

    def mkmount
        hash = mkmountargs()
        #hash[:provider] = @provider.name

        fakemodel = fakemodel(:mount, hash[:path])

        mount = @provider.new(fakemodel)
        #mount = Puppet.type(:mount).create(hash)

        hash.each do |name, val|
            fakemodel[name] = val
        end
        assert(mount, "Could not create provider mount")

        return mount
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @provider.filetype = Puppet::FileType.filetype(:ram)
    end

    def test_simplemount
        mkfaketype
        assert_nothing_raised {
            assert_equal([], @provider.retrieve)
        }

        # Now create a provider
        mount = nil
        assert_nothing_raised {
            mount = mkmount
        }

        # Make sure we're still empty
        assert_nothing_raised {
            assert_equal([], @provider.retrieve)
        }

        hash = mount.model.to_hash

        # Try storing it
        assert_nothing_raised do
            mount.store(hash)
        end

        # Make sure we get the mount back
        assert_nothing_raised {
            assert_equal([hash], @provider.retrieve)
        }

        # Now remove the whole object
        assert_nothing_raised {
            mount.store({})
            assert_equal([], @provider.retrieve)
        }
    end

    unless Facter["operatingsystem"].value == "Darwin"
        def test_mountsparse
            fakedataparse(fake_fstab) do
                # Now just make we've got some mounts we know will be there
                hashes = @provider.retrieve.find_all { |i| i.is_a? Hash }
                assert(hashes.length > 0, "Did not create any hashes")
                root = hashes.find { |i| i[:path] == "/" }
                assert(root, "Could not retrieve root mount")
            end
        end

        def test_rootfs
            fs = nil
            @provider.path = fake_fstab()
            fakemodel = fakemodel(:mount, "/")
            mount = @provider.new(fakemodel)
            mount.model[:path] = "/"
            assert(mount.hash, "Could not retrieve root fs")

            assert_nothing_raised {
                assert(mount.mounted?, "Root is considered not mounted")
            }
        end
    end

    if Puppet::SUIDManager.uid == 0
    def test_mountfs
        fs = nil
        case Facter["hostname"].value
        when "culain": fs = "/ubuntu"
        when "atalanta": fs = "/mnt"
        when "figurehead": fs = "/cg4/net/depts"
        else
            $stderr.puts "No mount for mount testing; skipping"
            return
        end

        oldtext = @provider.fileobj.read

        ftype = @provider.filetype

        # Make sure the original gets reinstalled.
        if ftype == Puppet::FileType.filetype(:netinfo)
            cleanup do 
                IO.popen("niload -r /mounts .", "w") do |file|
                    file.puts oldtext
                end
            end
        else
            cleanup do 
                @provider.fileobj.write(oldtext)
            end
        end

        fakemodel = fakemodel(:mount, "/")
        obj = @provider.new(fakemodel)
        obj.model[:path] = fs

        current = nil

        assert_nothing_raised {
            current = obj.mounted?
        }

        if current
            # Make sure the original gets reinstalled.
            cleanup do
                unless obj.mounted?
                    obj.mount
                end
            end
        end

        unless current
            assert_nothing_raised {
                obj.mount
            }
        end

        assert_nothing_raised {
            obj.unmount
        }
        assert(! obj.mounted?, "FS still mounted")
        assert_nothing_raised {
            obj.mount
        }
        assert(obj.mounted?, "FS not mounted")

    end
    end

    def fake_fstab
        os = Facter['operatingsystem']
        if os == "Solaris"
            name = "solaris.fstab"
        elsif os == "FreeBSD"
            name = "freebsd.fstab"
        else
            # Catchall for other fstabs
            name = "linux.fstab"
        end
        oldpath = @provider.path
        cleanup do @provider.path = oldpath end
        return fakefile(File::join("data/types/mount", name))
    end
end

# $Id$
