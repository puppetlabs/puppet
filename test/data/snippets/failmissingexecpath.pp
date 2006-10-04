define distloc($path) {
    file { "/tmp/exectesting1":
        ensure => file
    }
    exec { "touch $path":
        subscribe => File["/tmp/exectesting1"],
        refreshonly => true
    }
}

distloc { yay:
    path => "/tmp/execdisttesting",
}
