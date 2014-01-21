# $Id$

class base {
    file { "/tmp/classheir1": making_sure => file, mode => 755 }
}

class sub1 inherits base {
    file { "/tmp/classheir2": making_sure => file, mode => 755 }
}

class sub2 inherits base {
    file { "/tmp/classheir3": making_sure => file, mode => 755 }
}

include sub1, sub2
