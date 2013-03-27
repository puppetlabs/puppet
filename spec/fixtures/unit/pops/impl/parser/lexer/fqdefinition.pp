define one::two($ensure) {
    file { "/tmp/fqdefinition": ensure => $ensure }
}

one::two { "/tmp/fqdefinition": ensure => file }
