# $Id$

$file = "/tmp/defineoverrides1"

define myfile(mode) {
    file { $name: ensure => file, mode => $mode }
}

class base {
    myfile { $file: mode => 644 }
}

class sub inherits base {
    myfile { $file: mode => 755 }
}

include sub
