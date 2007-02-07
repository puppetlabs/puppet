#!/usr/bin/env ruby

$:.unshift("../../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/fileparsing'
require 'facter'

class TestParsedMounts < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::FileParsing

    def setup
        super
        @mount = Puppet.type(:mount)
        @provider = @mount.provider(:parsed)

        @oldfiletype = @provider.filetype
    end

    def teardown
        Puppet::FileType.filetype(:ram).clear
        @provider.filetype = @oldfiletype
        @provider.clear
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
            :name => "/fspuppet%s" % @pcount,
            :device => "/dev/dsk%s" % @pcount,
        }

        @provider.fields(:parsed).each do |field|
            unless args.include? field
                args[field] = "fake%s%s" % [field, @pcount]
            end
        end

        return args
    end

    def mkmount
        hash = mkmountargs()
        #hash[:provider] = @provider.name

        fakemodel = fakemodel(:mount, hash[:name])

        mount = @provider.new(fakemodel)
        assert(mount, "Could not create provider mount")
        hash[:record_type] = :parsed
        hash[:ensure] = :present
        mount.property_hash = hash

        return mount
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @provider.filetype = Puppet::FileType.filetype(:ram)
    end

    def test_default_target
        should = case Facter.value(:operatingsystem)
        when "Solaris": "/etc/vfstab"
        else
            "/etc/fstab"
        end
        assert_equal(should, @provider.default_target)
    end

    def test_simplemount
        mkfaketype
        target = @provider.default_target

        # Make sure we start with an empty file
        assert_equal("", @provider.target_object(target).read,
            "Got a non-empty starting file")

        # Now create a provider
        mount = nil
        assert_nothing_raised {
            mount = mkmount
        }

        # Make sure we're still empty
        assert_equal("", @provider.target_object(target).read,
            "Got a non-empty starting file")

        # Try flushing it to disk
        assert_nothing_raised do
            mount.flush
        end

        # Make sure it's now in the file.  The file format is validated in
        # the isomorphic methods.
        assert(@provider.target_object(target).read.include?("\t%s\t" %
            mount.property_hash[:name]), "Mount was not written to disk")

        # now make a change
        assert_nothing_raised { mount.dump = 5 }
        assert_nothing_raised { mount.flush }

        @provider.prefetch
        assert_equal(5, mount.dump, "did not flush change to disk")
    end

    unless Facter["operatingsystem"].value == "Darwin"
        def test_mountsparse
            tab = fake_fstab
            fakedataparse(tab) do
                # Now just make we've got some mounts we know will be there
                hashes = @provider.target_records(tab).find_all { |i| i.is_a? Hash }
                assert(hashes.length > 0, "Did not create any hashes")
                root = hashes.find { |i| i[:name] == "/" }
                assert(root, "Could not retrieve root mount")
            end
        end

        def test_rootfs
            fs = nil
            type = @mount.create :name => "/"

            provider = type.provider

            assert(FileTest.exists?(@provider.default_target),
                "FSTab %s does not exist" % @provider.default_target)
            assert_nothing_raised do
                @provider.prefetch
            end

            assert_equal(:present, provider.property_hash[:ensure],
                "Could not find root fs with provider %s" % provider.name)

            assert_nothing_raised {
                assert(provider.mounted?, "Root is considered not mounted")
            }
        end
    end

    if Puppet::SUIDManager.uid == 0 and Facter.value(:operatingsystem) != "Darwin"
    def test_mountfs
        fs = nil
        case Facter.value(:hostname)
        when "culain": fs = "/ubuntu"
        when "atalanta": fs = "/mnt"
        else
            $stderr.puts "No mount for mount testing; skipping"
            return
        end

        oldtext = @provider.target_object(@provider.default_target).read

        ftype = @provider.filetype

        mount = @mount.create :name => fs
        obj = mount.provider

        current = nil
        assert_nothing_raised {
            current = obj.mounted?
        }

        if current
            # Make sure the original gets remounted.
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
        # Check the actual output of df
        assert(! obj.df().include?(fs), "%s is still listed in df" % fs)
        assert_nothing_raised {
            obj.mount
        }
        assert(obj.mounted?, "FS not mounted")
        assert(obj.df().include?(fs), "%s is not listed in df" % fs)

        # Now try remounting
        assert_nothing_raised("Could not remount filesystem") do
            obj.remount
        end
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
        oldpath = @provider.default_target
        return fakefile(File::join("data/types/mount", name))
    end
end

# $Id$
