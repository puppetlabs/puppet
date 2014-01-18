# $Id$

file { "/tmp/singleary1":
    making_sure => file
}

file { "/tmp/singleary2":
    making_sure => file
}

file { "/tmp/singleary3":
    making_sure => file,
    require => [File["/tmp/singleary1"], File["/tmp/singleary2"]]
}

file { "/tmp/singleary4":
    making_sure => file,
    require => [File["/tmp/singleary1"]]
}
