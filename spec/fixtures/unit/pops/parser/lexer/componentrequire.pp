define testfile($mode) {
    file { $name: mode => $mode, ensure => present }
}

testfile { "/tmp/testing_component_requires2": mode => '0755' }

file { "/tmp/testing_component_requires1": mode => '0755', ensure => present,
    require => Testfile["/tmp/testing_component_requires2"] }
