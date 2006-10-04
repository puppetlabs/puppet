# $Id$

file { "/tmp/singleary1":
    ensure => file
}

file { "/tmp/singleary2":
    ensure => file
}

file { "/tmp/singleary3":
    ensure => file,
    require => [File["/tmp/singleary1"], File["/tmp/singleary2"]]
}

file { "/tmp/singleary4":
    ensure => file,
    require => [File["/tmp/singleary1"]]
}
