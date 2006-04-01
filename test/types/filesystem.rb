# Test host job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'puppet/type/parsedtype/filesystem'
require 'test/unit'
require 'facter'

class TestFilesystem < Test::Unit::TestCase
	include TestPuppet
    def setup
        super
        @filesystemtype = Puppet.type(:filesystem)
        @oldfiletype = @filesystemtype.filetype
    end

    def teardown
        @filesystemtype.filetype = @oldfiletype
        Puppet.type(:file).clear
        super
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        pfile = tempfile()
        old = @filesystemtype.path
        @filesystemtype.path = pfile

        cleanup do
            @filesystemtype.path = old
            @filesystemtype.fileobj = nil
        end

        # Reset this, just in case
        @filesystemtype.fileobj = nil
    end

    def mkfilesystem
        filesystem = nil

        if defined? @pcount
            @pcount += 1
        else
            @pcount = 1
        end
        args = {
            :path => "/fspuppet%s" % @pcount,
            :device => "/dev/dsk%s" % @pcount,
        }

        Puppet.type(:filesystem).fields.each do |field|
            unless args.include? field
                args[field] = "fake%s" % @pcount
            end
        end

        assert_nothing_raised {
            filesystem = Puppet.type(:filesystem).create(args)
        }

        return filesystem
    end

    def test_simplefilesystem
        mkfaketype
        host = nil
        assert_nothing_raised {
            assert_nil(Puppet.type(:filesystem).retrieve)
        }

        filesystem = mkfilesystem

        assert_nothing_raised {
            Puppet.type(:filesystem).store
        }

        assert_nothing_raised {
            assert(
                Puppet.type(:filesystem).to_file.include?(
                    Puppet.type(:filesystem).fileobj.read
                ),
                "File does not include all of our objects"
            )
        }
    end

    def test_filesystemsparse
        assert_nothing_raised {
            @filesystemtype.retrieve
        }

        # Now just make we've got some filesystems we know will be there
        root = @filesystemtype["/"]
        assert(root, "Could not retrieve root filesystem")
    end

    def test_rootfs
        fs = nil
        assert_nothing_raised {
            Puppet.type(:filesystem).retrieve
        }

        assert_nothing_raised {
            fs = Puppet.type(:filesystem)["/"]
        }
        assert(fs, "Could not retrieve root fs")

        assert_nothing_raised {
            assert(fs.mounted?, "Root is considered not mounted")
        }
    end

    # Make sure it reads and writes correctly.
    def test_readwrite
        assert_nothing_raised {
            Puppet::Type.type(:filesystem).retrieve
        }

        # Now switch to storing in ram
        mkfaketype

        fs = mkfilesystem

        assert(Puppet::Type.type(:filesystem).path != "/etc/fstab")

        assert_events([:filesystem_created], fs)

        text = Puppet::Type.type(:filesystem).fileobj.read

        assert(text =~ /#{fs[:path]}/, "Text did not include new fs")

        fs[:ensure] = :absent

        assert_events([:filesystem_removed], fs)
        text = Puppet::Type.type(:filesystem).fileobj.read

        assert(text !~ /#{fs[:path]}/, "Text still includes new fs")

        fs[:ensure] = :present

        assert_events([:filesystem_created], fs)

        text = Puppet::Type.type(:filesystem).fileobj.read

        assert(text =~ /#{fs[:path]}/, "Text did not include new fs")
    end

    if Process.uid == 0
    def test_mountfs
        fs = nil
        case Facter["hostname"].value
        when "culain": fs = "/ubuntu"
        else
            $stderr.puts "No filesystem for mount testing; skipping"
            return
        end

        backup = tempfile()

        FileUtils.cp(Puppet::Type.type(:filesystem).path, backup)

        # Make sure the original gets reinstalled.
        cleanup do 
            FileUtils.cp(backup, Puppet::Type.type(:filesystem).path)
        end

        Puppet.type(:filesystem).retrieve

        obj = Puppet.type(:filesystem)[fs]

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

        # Verify we can remove the filesystem
        assert_nothing_raised {
            obj[:ensure] = :absent
        }

        assert_events([:filesystem_removed], obj)

        # And verify it's gone
        assert(!obj.mounted?, "Object is mounted after being removed")

        text = Puppet.type(:filesystem).fileobj.read

        assert(text !~ /#{fs}/,
            "Fstab still contains %s" % fs)

        assert_raise(Puppet::Error, "Removed filesystem did not throw an error") {
            obj.mount
        }

        assert_nothing_raised {
            obj[:ensure] = :present
        }

        assert_events([:filesystem_created], obj)

        assert(File.read(Puppet.type(:filesystem).path) =~ /#{fs}/,
            "Fstab does not contain %s" % fs)

        assert(! obj.mounted?, "Object is mounted incorrectly")

        assert_nothing_raised {
            obj[:ensure] = :mounted
        }

        assert_events([:filesystem_mounted], obj)

        assert(File.read(Puppet.type(:filesystem).path) =~ /#{fs}/,
            "Fstab does not contain %s" % fs)

        assert(obj.mounted?, "Object is not mounted")

        unless current
            assert_nothing_raised {
                obj.unmount
            }
        end
    end
    end
end

# $Id$
