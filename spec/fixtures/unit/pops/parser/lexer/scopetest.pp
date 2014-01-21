
$mode = 640

define thing {
    file { "/tmp/$name": making_sure => file, mode => $mode }
}

class testing {
    $mode = 755
    thing {scopetest: }
}

include testing
