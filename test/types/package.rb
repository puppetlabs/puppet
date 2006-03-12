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

unless Puppet.type(:package).default
    puts "No default package type for %s; skipping package tests" % $platform
else

class TestPackageSource < Test::Unit::TestCase
	include TestPuppet
    def test_filesource
        path = tempfile()
        system("touch %s" % path)
        assert_equal(
            path,
            Puppet::PackageSource.get("file://#{path}")
        )
    end
end

class TestPackages < Test::Unit::TestCase
	include FileTesting
    def setup
        super
        #@list = Puppet.type(:package).getpkglist
        Puppet.type(:package).clear
    end

    # These are packages that we're sure will be installed
    def installedpkgs
        pkgs = nil
        case $platform
        when "SunOS"
            pkgs = %w{SMCossh}
        when "Debian": pkgs = %w{ssh openssl}
        when "Fedora": pkgs = %w{openssh}
        when "OpenBSD": pkgs = %{vim}
        else
            Puppet.notice "No test package for %s" % $platform
            return []
        end

        return pkgs
    end

    def mkpkgs
        tstpkgs().each { |pkg|
            if pkg.is_a?(Array)
                hash = {:name => pkg[0], :source => pkg[1]}
                hash[:ensure] = "present"

                unless File.exists?(hash[:source])
                    Puppet.info "No package file %s for %s; skipping some package tests" %
                        [hash[:source], Facter["operatingsystem"].value]
                end
                yield Puppet.type(:package).create(hash)
            else
                yield Puppet.type(:package).create(
                    :name => pkg, :ensure => "latest"
                )
            end
        }
    end

    def tstpkgs
        retval = []
        case $platform
        when "Solaris":
            arch = Facter["hardwareisa"].value + Facter["operatingsystemrelease"].value
            case arch
            when "sparc5.8":
                retval = [["SMCarc", "/usr/local/pkg/arc-5.21e-sol8-sparc-local"]]
            when "i3865.8":
                retval = [["SMCarc", "/usr/local/pkg/arc-5.21e-sol8-intel-local"]]
            end
        when "OpenBSD":
            retval = [["aalib", "ftp://ftp.usa.openbsd.org/pub/OpenBSD/3.8/packages/i386/aalib-1.2-no_x11.tgz"]]
        when "Debian":
            retval = %w{zec}
        #when "RedHat": type = :rpm
        when "Fedora":
            retval = %w{wv}
        when "CentOS":
            retval = [%w{enhost /home/luke/rpm/RPMS/noarch/enhost-1.0.2-1.noarch.rpm}]
        else
            Puppet.notice "No test packages for %s" % $platform
        end

        return retval
    end

    def mkpkgcomp(pkg)
        assert_nothing_raised {
            pkg = Puppet.type(:package).create(:name => pkg, :ensure => "present")
        }
        assert_nothing_raised {
            pkg.retrieve
        }

        comp = newcomp("package", pkg)

        return comp
    end

    def test_retrievepkg
        installedpkgs().each { |pkg|
            obj = nil
            assert_nothing_raised {
                obj = Puppet.type(:package).create(
                    :name => pkg
                )
            }

            assert(obj, "could not create package")

            assert_nothing_raised {
                obj.retrieve
            }

            assert(obj[:version], "Could not retrieve package version")
        }
    end

    def test_nosuchpkg
        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:package).create(
                :name => "thispackagedoesnotexist"
            )
        }

        assert_nothing_raised {
            obj.retrieve
        }

        assert_equal(:absent, obj.is(:ensure),
            "Somehow retrieved unknown pkg's version")
    end

    def test_specifypkgtype
        assert_nothing_raised {
            pkg = Puppet.type(:package).create(
                :name => "mypkg",
                :type => "yum"
            )
        }
    end

    def test_latestpkg
        tstpkgs { |pkg|
            assert_nothing_raised {
                assert(pkg.latest, "Package did not return value for 'latest'")
            }
        }
    end

    unless Process.uid == 0
        $stderr.puts "Run as root to perform package installation tests"
    else
    def test_installpkg
        mkpkgs { |pkg|
            # we first set install to 'true', and make sure something gets
            # installed
            assert_nothing_raised {
                pkg.retrieve
            }

            if pkg.insync?
                Puppet.notice "Test package %s is already installed; please choose a different package for testing" % pkg
                next
            end

            comp = newcomp("package", pkg)

            assert_events([:package_created], comp, "package")

            # then uninstall it
            assert_nothing_raised {
                pkg[:ensure] = "absent"
            }


            pkg.retrieve

            assert(! pkg.insync?, "Package is in sync")

            assert_events([:package_removed], comp, "package")

            # and now set install to 'latest' and verify it installs
            # FIXME this isn't really a very good test -- we should install
            # a low version, and then upgrade using this.  But, eh.
            if pkg.respond_to?(:latest)
                assert_nothing_raised {
                    pkg[:ensure] = "latest"
                }

                assert_events([:package_created], comp, "package")

                pkg.retrieve
                assert(pkg.insync?, "After install, package is not insync")

                assert_nothing_raised {
                    pkg[:ensure] = "absent"
                }

                pkg.retrieve

                assert(! pkg.insync?, "Package is insync")

                assert_events([:package_removed], comp, "package")
            end
        }
    end

    case Facter["operatingsystem"].value
    when "CentOS":
        def test_upgradepkg
            first = "/home/luke/rpm/RPMS/noarch/enhost-1.0.1-1.noarch.rpm"
            second = "/home/luke/rpm/RPMS/noarch/enhost-1.0.2-1.noarch.rpm"

            unless FileTest.exists?(first) and FileTest.exists?(second)
                $stderr.puts "Could not find upgrade test pkgs; skipping"
                return
            end

            pkg = nil
            assert_nothing_raised {
                pkg = Puppet.type(:package).create(
                    :name => "enhost",
                    :ensure => :latest,
                    :source => first
                )
            }

            assert_events([:package_created], pkg)

            assert_nothing_raised {
                pkg.retrieve
            }
            assert(pkg.insync?, "Package is not in sync")
            pkg.clear
            assert_nothing_raised {
                pkg[:source] = second
            }
            assert_events([:package_changed], pkg)

            assert_nothing_raised {
                pkg.retrieve
            }
            assert(pkg.insync?, "Package is not in sync")
            assert_nothing_raised {
                pkg[:ensure] = :absent
            }
            assert_events([:package_removed], pkg)

            assert_nothing_raised {
                pkg.retrieve
            }
            assert(pkg.insync?, "Package is not in sync")
        end
    end
    end
end
end

# $Id$
