if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'
require 'facter'

Puppet[:loglevel] = :debug if __FILE__ == $0

# $Id$

class TestPackagingType < Test::Unit::TestCase
    def test_listing
        platform = Facter["operatingsystem"].value
        type = nil
        case platform
        when "SunOS"
            type = "sunpkg"
        when "Linux"
            case Facter["distro"].value
            when "Debian": type = "dpkg"
            when "RedHat": type = "rpm"
            else
                #raise "No default type for " + Facter["distro"].to_s
                Puppet.warning "Defaulting to 'rpm' for packaging"
                type = "rpm"
            end
        else
            type = :invalid
        end

        assert_nothing_raised() {
            Puppet::PackagingType[type].list
        }
    end
end

class TestPackageSource < Test::Unit::TestCase
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
    def setup
        @list = Puppet::Type::Package.getpkglist
    end

    def teardown
        Puppet::Type::Package.clear
    end

    def test_checking
        pkg = nil
        assert_nothing_raised() {
            pkg = @list[rand(@list.length)]
        }
        assert(pkg[:install])
        assert(! pkg.state(:install).should)
        assert_nothing_raised() {
            pkg.evaluate
        }
        assert_nothing_raised() {
            pkg[:install] = pkg[:install]
        }
        assert_nothing_raised() {
            pkg.evaluate
        }
        assert(pkg.insync?)
        assert_nothing_raised() {
            pkg[:install] = "1.2.3.4"
        }
        assert(!pkg.insync?)
    end
end
