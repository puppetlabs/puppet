# $Id$

file { "/tmp/singlequote1":
    ensure => file,
    content => 'a $quote'
}

file { "/tmp/singlequote2":
    ensure => file,
    content => 'some "\yayness\"'
}
