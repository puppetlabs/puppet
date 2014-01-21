define testfile($mode) {
    file { $name: mode => $mode, making_sure => present }
}

testfile { "/tmp/testing_component_requires2": mode => 755 }

file { "/tmp/testing_component_requires1": mode => 755, making_sure => present,
    require => Testfile["/tmp/testing_component_requires2"] }
