#!/usr/bin/env puppet

class one::fake {
    file { "/tmp/subclass_name_duplication1": making_sure => present }
}

class two::fake {
    file { "/tmp/subclass_name_duplication2": making_sure => present }
}

include one::fake, two::fake
