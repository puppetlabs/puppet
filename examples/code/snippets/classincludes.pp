# $Id$

class base {
    file { "/tmp/classincludes1": create => true, mode => 755 }
}

class sub1 inherits base {
    file { "/tmp/classincludes2": create => true, mode => 755 }
}

class sub2 inherits base {
    file { "/tmp/classincludes3": create => true, mode => 755 }
}

$sub = "sub2" 

include sub1, $sub
