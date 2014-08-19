# $Id$

define testargs($file, $mode = '0755') {
    file { $file: ensure => file, mode => $mode }
}

testargs { "testingname":
    file => "/tmp/argumenttest1"
}

testargs { "testingother":
    file => "/tmp/argumenttest2",
    mode => '0644'
}
