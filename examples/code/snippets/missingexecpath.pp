define distloc(path) {
    file { "/tmp/exectesting1":
        create => file
    }
    exec { "touch $path":
        subscribe => file["/tmp/exectesting1"],
        refreshonly => true
    }
}

distloc {
    path => "/tmp/execdisttesting",
}
