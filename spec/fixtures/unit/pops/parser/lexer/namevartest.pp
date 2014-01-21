define filetest($mode, $making_sure = file) {
    file { $name:
        mode => $mode,
        making_sure => $making_sure
    }
}

filetest { "/tmp/testfiletest": mode => 644}
filetest { "/tmp/testdirtest": mode => 755, making_sure => directory}
