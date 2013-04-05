# $Id$

$var = "value"

file { "/tmp/snippetselectatest":
    ensure => file,
    mode => $var ? {
        nottrue => 641,
        value => 755
    }
}

file { "/tmp/snippetselectbtest":
    ensure => file,
    mode => $var ? {
        nottrue => 644,
        default => 755
    }
}

$othervar = "complex value"

file { "/tmp/snippetselectctest":
    ensure => file,
    mode => $othervar ? {
        "complex value" => 755,
        default => 644
    }
}
$anothervar = Yayness

file { "/tmp/snippetselectdtest":
    ensure => file,
    mode => $anothervar ? {
        Yayness => 755,
        default => 644
    }
}
