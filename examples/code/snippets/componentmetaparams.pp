file { "/tmp/component1":
    ensure => file
}

define thing {
    file { $name: ensure => file }
}

thing { "/tmp/component2":
    require => file["/tmp/component1"]
}
