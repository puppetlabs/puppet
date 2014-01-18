# $Id$

define mytype {
    file { "/tmp/classtest": making_sure => file, mode => 755 }
}

class testing {
    mytype { "componentname": }
}

include testing
