file { "/tmp/component1":
    making_sure => file
}

define thing {
    file { $name: making_sure => file }
}

thing { "/tmp/component2":
    require => File["/tmp/component1"]
}
