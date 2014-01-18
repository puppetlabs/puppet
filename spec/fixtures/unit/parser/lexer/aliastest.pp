file { "a file":
    path => "/tmp/aliastest",
    making_sure => file
}

file { "another":
    path => "/tmp/aliastest2",
    making_sure => file,
    require => File["a file"]
}

file { "a third":
    path => "/tmp/aliastest3",
    making_sure => file,
    require => File["/tmp/aliastest"]
}
