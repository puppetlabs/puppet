define filetest($mode, $ensure = file) {
    file { $name:
        mode => $mode,
        ensure => $ensure
    }
}

filetest { "/tmp/testfiletest": mode => 644}
filetest { "/tmp/testdirtest": mode => 755, ensure => directory}
