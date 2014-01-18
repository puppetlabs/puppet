# $Id$

$file = "/tmp/defineoverrides1"

define myfile($mode) {
    file { $name: making_sure => file, mode => $mode }
}

class base {
    myfile { $file: mode => 644 }
}

class sub inherits base {
    Myfile[$file] { mode => 755, } # test the end-comma
}

include sub
