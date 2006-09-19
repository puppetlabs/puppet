# Test host job creation, modification, and destruction

require 'puppettest'
require 'puppet'
require 'puppet/type/parsedtype/mount'
require 'facter'

class TestMounts < Test::Unit::TestCase
	include PuppetTest
    def setup
        super
        @mounttype = Puppet.type(:mount)
        @oldfiletype = @mounttype.filetype
    end

    def teardown
        @mounttype.filetype = @oldfiletype
        Puppet.type(:file).clear
        super
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        pfile = tempfile()
        old = @mounttype.filetype
        @mounttype.filetype = Puppet::FileType.filetype(:ram)

        cleanup do
            @mounttype.filetype = old
            @mounttype.fileobj = nil
        end

        # Reset this, just in case
        @mounttype.fileobj = nil
    end

    def mkmount
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

        Puppet.type(:mount).fields.each do |field|
            unless args.include? field
                args[field] = "fake%s" % @pcount
            end
        end

        assert_nothing_raised {
            mount = Puppet.type(:mount).create(args)
        }

        return mount
    end

    def test_simplemount
        mkfaketype
        host = nil
        assert_nothing_raised {
            assert_nil(Puppet.type(:mount).retrieve)
        }

        mount = mkmount

        assert_nothing_raised {
            Puppet.type(:mount).store
        }

        assert_nothing_raised {
            assert(
                Puppet.type(:mount).to_file.include?(
                    Puppet.type(:mount).fileobj.read
                ),
                "File does not include all of our objects"
            )
        }
    end

    unless Facter["operatingsystem"].value == "Darwin"
        def test_mountsparse
            use_fake_fstab
            assert_nothing_raised {
                @mounttype.retrieve
            }

            # Now just make we've got some mounts we know will be there
            root = @mounttype["/"]
            assert(root, "Could not retrieve root mount")
        end

        def test_rootfs
            fs = nil
            use_fake_fstab
            assert_nothing_raised {
                Puppet.type(:mount).retrieve
            }

            assert_nothing_raised {
                fs = Puppet.type(:mount)["/"]
            }
            assert(fs, "Could not retrieve root fs")

            assert_nothing_raised {
                assert(fs.mounted?, "Root is considered not mounted")
            }
        end
    end

    # Make sure it reads and writes correctly.
    def test_readwrite
        use_fake_fstab
        assert_nothing_raised {
            Puppet::Type.type(:mount).retrieve
        }

        oldtype = Puppet::Type.type(:mount).filetype

        # Now switch to storing in ram
        mkfaketype

        fs = mkmount

        assert(Puppet::Type.type(:mount).filetype != oldtype)

        assert_events([:mount_created], fs)

        text = Puppet::Type.type(:mount).fileobj.read

        assert(text =~ /#{fs[:path]}/, "Text did not include new fs")

        fs[:ensure] = :absent

        assert_events([:mount_removed], fs)
        text = Puppet::Type.type(:mount).fileobj.read

        assert(text !~ /#{fs[:path]}/, "Text still includes new fs")

        fs[:ensure] = :present

        assert_events([:mount_created], fs)

        text = Puppet::Type.type(:mount).fileobj.read

        assert(text =~ /#{fs[:path]}/, "Text did not include new fs")

        fs[:options] = "rw,noauto"

        assert_events([:mount_changed], fs)
    end

    if Process.uid == 0
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

        assert_nothing_raised {
            Puppet.type(:mount).retrieve
        }

        oldtext = Puppet::Type.type(:mount).fileobj.read

        ftype = Puppet::Type.type(:mount).filetype

        # Make sure the original gets reinstalled.
        if ftype == Puppet::FileType.filetype(:netinfo)
            cleanup do 
                IO.popen("niload -r /mounts .", "w") do |file|
                    file.puts oldtext
                end
            end
        else
            cleanup do 
                Puppet::Type.type(:mount).fileobj.write(oldtext)
            end
        end

        obj = Puppet.type(:mount)[fs]

        assert(obj, "Could not retrieve %s object" % fs)

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

        # Now copy all of the states' "is" values to the "should" values
        obj.each do |state|
            state.should = state.is
        end

        # Verify we can remove the mount
        assert_nothing_raised {
            obj[:ensure] = :absent
        }

        assert_events([:mount_removed], obj)
        assert_events([], obj)

        # And verify it's gone
        assert(!obj.mounted?, "Object is mounted after being removed")

        text = Puppet.type(:mount).fileobj.read

        assert(text !~ /#{fs}/,
            "Fstab still contains %s" % fs)

        assert_nothing_raised {
            obj[:ensure] = :present
        }

        assert_events([:mount_created], obj)
        assert_events([], obj)

        text = Puppet::Type.type(:mount).fileobj.read
        assert(text =~ /#{fs}/, "Fstab does not contain %s" % fs)

        assert(! obj.mounted?, "Object is mounted incorrectly")

        assert_nothing_raised {
            obj[:ensure] = :mounted
        }

        assert_events([:mount_mounted], obj)
        assert_events([], obj)

        text = Puppet::Type.type(:mount).fileobj.read
        assert(text =~ /#{fs}/,
            "Fstab does not contain %s" % fs)

        obj.retrieve
        assert(obj.mounted?, "Object is not mounted")

        unless current
            assert_nothing_raised {
                obj.unmount
            }
        end
    end
    end

    def use_fake_fstab
        os = Facter['operatingsystem']
        if os == "Solaris"
            name = "solaris.fstab"
        elsif os == "FreeBSD"
            name = "freebsd.fstab"
        else
            # Catchall for other fstabs
            name = "linux.fstab"
        end
        fstab = fakefile(File::join("data/types/mount", name))
        Puppet::Type.type(:mount).path = fstab
    end
end

# $Id$
