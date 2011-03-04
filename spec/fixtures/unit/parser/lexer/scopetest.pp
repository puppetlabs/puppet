
$mode = 640

define thing {
    file { "/tmp/$name": ensure => file, mode => $mode }
}

class testing {
    $mode = 755
    thing {scopetest: }
}

include testing
