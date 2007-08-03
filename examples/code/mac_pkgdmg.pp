#!/usr/bin/env puppet
#

package
{
    "Foobar.pkg.dmg": ensure => present, provider => pkgdmg;
}
