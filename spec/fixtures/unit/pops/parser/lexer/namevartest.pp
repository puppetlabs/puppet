define filetest($mode, $ensure = file) {
    file { $name:
        mode => $mode,
        ensure => $ensure
    }
}

filetest { "/tmp/testfiletest": mode => '0644'}
filetest { "/tmp/testdirtest": mode => '0755', ensure => directory}
