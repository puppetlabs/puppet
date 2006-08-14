# At this point, it's an exact copy of the Blastwave stuff.
Puppet::Type.type(:package).provide :sunfreeware, :parent => :blastwave do
    desc "Package management using sunfreeware.com's ``pkg-get`` command on Solaris.
        At this point, support is exactly the same as ``blastwave`` support and
        has not actually been tested."
    if pkgget = binary("pkg-get")
        PKGGET = pkgget
    else
        PKGGET = nil
    end

    confine :exists => PKGGET
end

# $Id$
