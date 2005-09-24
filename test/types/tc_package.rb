if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

$platform = Facter["operatingsystem"].value

unless Puppet::Type::Package.default
    puts "No default package type for %s; skipping package tests" % $platform
else

class TestPackageSource < TestPuppet
    def test_filesource
        system("touch /tmp/fakepackage")
        assert_equal(
            "/tmp/fakepackage",
            Puppet::PackageSource.get("file:///tmp/fakepackage")
        )
        system("rm -f /tmp/fakepackage")
    end
end

class TestPackages < FileTesting
    def setup
        #@list = Puppet::Type::Package.getpkglist
        Puppet::Type::Package.clear
        super
    end

    def mkpkgcomp(pkg)
        assert_nothing_raised {
            pkg = Puppet::Type::Package.create(:name => pkg, :install => true)
        }
        assert_nothing_raised {
            pkg.retrieve
        }

        comp = newcomp("package", pkg)

        return comp
    end

    def test_retrievepkg
        pkg = nil

        case $platform
        when "SunOS"
            pkg = "SMCossh"
        when "Linux"
            case Facter["distro"].value
            when "Debian": pkg = "ssh"
            #when "RedHat": type = :rpm
            else
                Puppet.notice "No test package for %s" % $platform 
                return
            end
        else
            Puppet.notice "No test package for %s" % $platform
            return
        end

        obj = nil
        assert_nothing_raised {
            obj = Puppet::Type::Package.create(
                :name => pkg
            )
        }

        assert(obj, "could not create package")

        assert_nothing_raised {
            obj.retrieve
        }

        assert(obj.is(:install), "Could not retrieve package version")
    end

    def test_nosuchpkg
        obj = nil
        assert_nothing_raised {
            obj = Puppet::Type::Package.create(
                :name => "thispackagedoesnotexist"
            )
        }

        assert_nothing_raised {
            obj.retrieve
        }

        assert_equal(:notinstalled, obj.is(:install),
            "Somehow retrieved unknown pkg's version")
    end

    unless Process.uid == 0
        $stderr.puts "Run as root to perform package installation tests"
    else
    def test_installpkg
        pkgs = nil
        case $platform
        #when "SunOS"
        #    type = "sunpkg"
        when "Linux"
            case Facter["distro"].value
            when "Debian":
                pkgs = %w{zec}
            #when "RedHat": type = :rpm
            else
                Puppet.notice "No test packags for %s" % $platform
                return
            end
        else
            Puppet.notice "No test packags for %s" % $platform
            return
        end

        pkgs.each { |pkg|
            assert_nothing_raised {
                pkg = Puppet::Type::Package.create(:name => pkg, :install => true)
            }
            assert_nothing_raised {
                pkg.retrieve
            }

            if pkg.insync?
                Puppet.notice "Test package %s is already installed; please choose a different package for testing" % pkg
                next
            end

            comp = newcomp("package", pkg)

            assert_events(comp, [:package_installed], "package")

            assert_nothing_raised {
                pkg[:install] = false
            }

            pkg.retrieve

            assert(! pkg.insync?, "Package is insync")

            assert_events(comp, [:package_removed], "package")
        }
    end
    end
end
end

# $Id$
