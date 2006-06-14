module Puppet
    # OS X Packaging sucks.  We can install packages, but that's about it.
    Puppet.type(:package).newpkgtype(:apple) do
        def query
            if FileTest.exists?("/Library/Receipts/#{self[:name]}.pkg")
                return {:name => self[:name], :ensure => :present}
            else
                return nil
            end
        end

        def install
            source = nil
            unless source = self[:source]
                self.fail "Mac OS X packages must specify a package source"
            end

            output = %x{/usr/sbin/installer -pkg #{source} -target / 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        def list
            packages = []

            Dir.entries("/Library/Receipts").find { |f|
                f =~ /\.pkg$/
            }.collect { |f|
                Puppet.type(:package).installedpkg(
                    :name => f.sub(/\.pkg/, ''),
                    :type => :apple,
                    :ensure => :installed
                )
            }
        end
    end
end

# $Id$
