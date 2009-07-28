$value1 = ""
$value2 = true
$value3 = false
$value4 = yay

$test = "yay"

$mode1 = $value1 ? {
    "" => 755,
    default => 644
}

$mode2 = $value2 ? {
    true => 755,
    default => 644
}

$mode3 = $value3 ? {
    false => 755,
    default => 644
}

$mode4 = $value4 ? {
    $test => 755,
    default => 644
}

$mode5 = yay ? {
    $test => 755,
    default => 644
}

$mode6 = $mode5 ? {
    755 => 755
}

$mode7 = "test regex" ? {
    /regex$/ => 755,
    default => 644
}


file { "/tmp/selectorvalues1": ensure => file, mode => $mode1 }
file { "/tmp/selectorvalues2": ensure => file, mode => $mode2 }
file { "/tmp/selectorvalues3": ensure => file, mode => $mode3 }
file { "/tmp/selectorvalues4": ensure => file, mode => $mode4 }
file { "/tmp/selectorvalues5": ensure => file, mode => $mode5 }
file { "/tmp/selectorvalues6": ensure => file, mode => $mode6 }
file { "/tmp/selectorvalues7": ensure => file, mode => $mode7 }
