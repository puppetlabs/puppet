define distloc(path) {
    file { "/tmp/exectesting1":
        ensure => file
    }
    exec { "touch $path":
        subscribe => file["/tmp/exectesting1"],
        refreshonly => true
    }
}

distloc {
    path => "/tmp/execdisttesting",
}
