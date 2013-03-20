# $Id$

define mytype {
    file { "/tmp/classtest": ensure => file, mode => 755 }
}

class testing {
    mytype { "componentname": }
}

include testing
