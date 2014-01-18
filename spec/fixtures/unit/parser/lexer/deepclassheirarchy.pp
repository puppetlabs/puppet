# $Id$

class base {
    file { "/tmp/deepclassheir1": making_sure => file, mode => 755 }
}

class sub1 inherits base {
    file { "/tmp/deepclassheir2": making_sure => file, mode => 755 }
}

class sub2 inherits sub1 {
    file { "/tmp/deepclassheir3": making_sure => file, mode => 755 }
}

class sub3 inherits sub2 {
    file { "/tmp/deepclassheir4": making_sure => file, mode => 755 }
}

class sub4 inherits sub3 {
    file { "/tmp/deepclassheir5": making_sure => file, mode => 755 }
}

include sub4
