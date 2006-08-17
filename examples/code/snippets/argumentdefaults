# $Id$

define testargs($file, $mode = 755) {
    file { $file: ensure => file, mode => $mode }
}

testargs { "testingname":
    file => "/tmp/argumenttest1"
}

testargs { "testingother":
    file => "/tmp/argumenttest2",
    mode => 644
}
