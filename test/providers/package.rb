require 'etc'
require 'puppet/type'
require 'puppettest'

class TestPackageProvider < Test::Unit::TestCase
	include PuppetTest
    def setup
        super
        @provider = nil
        assert_nothing_raised {
            @provider = Puppet::Type.type(:package).defaultprovider
        }

        assert(@provider, "Could not find default package provider")
        assert(@provider.name != :fake, "Got a fake provider")
    end

    def test_nothing
    end

    if Facter["operatingsystem"].value == "Solaris" and Process.uid == 0
    if Puppet.type(:package).provider(:blastwave).suitable?
    # FIXME The packaging crap needs to be rewritten to support testing
    # multiple package types on the same platform.
    def test_list_blastwave
        pkgs = nil
        assert_nothing_raised {
            pkgs = Puppet::Type.type(:package).provider(:blastwave).list
        }

        pkgs.each do |pkg|
            if pkg[:name] =~ /^CSW/
                assert_equal(:blastwave, pkg[:provider],
                    "Type was not set correctly")
            end
        end
    end

    def test_install_blastwave
        pkg = nil
        name = "cabextract"
        model = fakemodel(:package, name)
        assert_nothing_raised {
            pkg = Puppet::Type.type(:package).provider(:blastwave).new(model)
        }

        if hash = pkg.query and hash[:ensure] != :absent
            p hash
            $stderr.puts "Cannot test pkg installation; %s is already installed" %
                name
            return
        end

        assert_nothing_raised {
            pkg.install
        }

        hash = nil
        assert(hash = pkg.query,
            "package did not install")
        assert(hash[:ensure] != :absent,
            "package did not install")

        latest = nil
        assert_nothing_raised {
            latest = pkg.latest
        }
        assert(latest, "Could not find latest package version")
        assert_nothing_raised {
            pkg.uninstall
        }
    end
    else
        $stderr.puts "No pkg-get scripting; skipping blastwave tests"
    end
    end
end

# $Id$
