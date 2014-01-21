# $Id$

$var = "value"

file { "/tmp/snippetselectatest":
    making_sure => file,
    mode => $var ? {
        nottrue => 641,
        value => 755
    }
}

file { "/tmp/snippetselectbtest":
    making_sure => file,
    mode => $var ? {
        nottrue => 644,
        default => 755
    }
}

$othervar = "complex value"

file { "/tmp/snippetselectctest":
    making_sure => file,
    mode => $othervar ? {
        "complex value" => 755,
        default => 644
    }
}
$anothervar = Yayness

file { "/tmp/snippetselectdtest":
    making_sure => file,
    mode => $anothervar ? {
        Yayness => 755,
        default => 644
    }
}
