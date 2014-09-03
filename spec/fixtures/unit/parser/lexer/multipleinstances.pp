# $Id$

file {
    "/tmp/multipleinstancesa": ensure => file, mode => '0755';
    "/tmp/multipleinstancesb": ensure => file, mode => '0755';
    "/tmp/multipleinstancesc": ensure => file, mode => '0755';
}
