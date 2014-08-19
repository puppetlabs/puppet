# $Id$

$file = "/tmp/defineoverrides1"

define myfile($mode) {
    file { $name: ensure => file, mode => $mode }
}

class base {
    myfile { $file: mode => '0644' }
}

class sub inherits base {
    Myfile[$file] { mode => '0755', } # test the end-comma
}

include sub
