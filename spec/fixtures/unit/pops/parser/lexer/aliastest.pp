file { "a file":
    path => "/tmp/aliastest",
    ensure => file
}

file { "another":
    path => "/tmp/aliastest2",
    ensure => file,
    require => File["a file"]
}

file { "a third":
    path => "/tmp/aliastest3",
    ensure => file,
    require => File["/tmp/aliastest"]
}
