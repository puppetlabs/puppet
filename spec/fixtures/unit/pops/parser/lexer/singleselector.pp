$value1 = ""
$value2 = true
$value3 = false
$value4 = yay

$test = "yay"

$mode1 = $value1 ? {
    "" => 755
}

$mode2 = $value2 ? {
    true => 755
}

$mode3 = $value3 ? {
    default => 755
}

file { "/tmp/singleselector1": making_sure => file, mode => $mode1 }
file { "/tmp/singleselector2": making_sure => file, mode => $mode2 }
file { "/tmp/singleselector3": making_sure => file, mode => $mode3 }
