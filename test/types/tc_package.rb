if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

Puppet[:loglevel] = :debug if __FILE__ == $0

# $Id$

$platform = Facter["operatingsystem"].value

class TestPackagingType < Test::Unit::TestCase
    def teardown
        Puppet::Type::Package.clear
    end

    def test_listing
        type = Puppet::Type::Package.defaulttype
        assert(type)

        #assert_nothing_raised() {
        #    type.list(nil)
        #}
    end
end

class TestPackageSource < Test::Unit::TestCase
    def teardown
        Puppet::Type::Package.clear
    end

    def test_filesource
        system("touch /tmp/fakepackage")
        assert_equal(
            "/tmp/fakepackage",
            Puppet::PackageSource.get("file:///tmp/fakepackage")
        )
        system("rm -f /tmp/fakepackage")
    end
end

class TestPackages < Test::Unit::TestCase
    include FileTesting
    def setup
        #@list = Puppet::Type::Package.getpkglist
        Puppet::Type::Package.clear
    end

    def teardown
        Puppet::Type::Package.clear
    end

    def mkpkgcomp(pkg)
        assert_nothing_raised {
            pkg = Puppet::Type::Package.new(:name => pkg, :install => true)
        }
        assert_nothing_raised {
            pkg.retrieve
        }

        comp = newcomp("package", pkg)

        return comp
    end

    def test_checking
#        pkg = nil
#        assert_nothing_raised() {
#            pkg = @list[rand(@list.length)]
#        }
#        assert(pkg[:install])
#        assert(! pkg.state(:install).should)
#        assert_nothing_raised() {
#            pkg.evaluate
#        }
#        assert_nothing_raised() {
#            pkg[:install] = pkg[:install]
#        }
#        assert_nothing_raised() {
#            pkg.evaluate
#        }
#        assert(pkg.insync?)
#        assert_nothing_raised() {
#            pkg[:install] = "1.2.3.4"
#        }
#        assert(!pkg.insync?)
    end

    def test_retrievepkg
        pkg = nil

        case $platform
        #when "SunOS"
        #    type = "SMCossh"
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
            obj = Puppet::Type::Package.new(
                :name => pkg
            )
        }

        assert_nothing_raised {
            obj.retrieve
        }
    end

    def test_zinstallpkg
        unless Process.uid == 0
            Puppet.notice "Test as root for installation tests"
            return
        end
        pkgs = nil
        case $platform
        #when "SunOS"
        #    type = "sunpkg"
        when "Linux"
            case Facter["distro"].value
            when "Debian": type = :apt
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
                pkg = Puppet::Type::Package.new(:name => pkg, :install => true)
            }
            assert_nothing_raised {
                pkg.retrieve
            }

            if pkg.insync?
                Puppet.notice "Test package %s is already installed; please choose a different package for testing" % pkg
                next
            end

            comp = newcomp("package", pkg)
            trans = nil
            assert_nothing_raised {
                trans = comp.evaluate
            }
            events = nil
            assert_nothing_raised {
                events = trans.evaluate.collect { |event| event.event }
            }
            assert_equal([:package_installed],events)

            assert_nothing_raised {
                pkg[:install] = false
            }

            assert_nothing_raised {
                comp.retrieve
            }
            assert_nothing_raised {
               trans = comp.evaluate
            }
            assert_nothing_raised {
                events = trans.evaluate.collect { |event| event.event }
            }
            assert_equal([:package_removed],events)
        }
    end
end
