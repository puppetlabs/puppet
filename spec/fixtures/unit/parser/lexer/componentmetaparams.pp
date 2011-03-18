file { "/tmp/component1":
    ensure => file
}

define thing {
    file { $name: ensure => file }
}

thing { "/tmp/component2":
    require => File["/tmp/component1"]
}
