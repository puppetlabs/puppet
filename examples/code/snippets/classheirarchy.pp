# $Id$

class base {
    file { "/tmp/classheir1": create => true, mode => 755 }
}

class sub1 inherits base {
    file { "/tmp/classheir2": create => true, mode => 755 }
}

class sub2 inherits base {
    file { "/tmp/classheir3": create => true, mode => 755 }
}

sub1 {}
sub2 {}
