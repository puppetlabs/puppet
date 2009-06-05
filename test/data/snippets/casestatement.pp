# $Id$

$var = "value"

case $var {
  "nope": {
     file { "/tmp/fakefile": mode => 644, ensure => file }
  }
  "value": {
     file { "/tmp/existsfile": mode => 755, ensure => file }
  }
}

$ovar = "yayness"

case $ovar {
    "fooness": {
         file { "/tmp/nostillexistsfile": mode => 644, ensure => file }
    }
    "booness", "yayness": {
        case $var {
            "nep": {
                 file { "/tmp/noexistsfile": mode => 644, ensure => file }
            }
            "value": {
                 file { "/tmp/existsfile2": mode => 755, ensure => file }
            }
        }
    }
}

case $ovar {
    "fooness": {
         file { "/tmp/nostillexistsfile": mode => 644, ensure => file }
    }
    default: {
        file { "/tmp/existsfile3": mode => 755, ensure => file }
    }
}

$bool = true

case $bool {
    true: {
        file { "/tmp/existsfile4": mode => 755, ensure => file }
    }
}

$yay = yay
$a = yay
$b = boo

case $yay {
    $a: { file { "/tmp/existsfile5": mode => 755, ensure => file } }
    $b: { file { "/tmp/existsfile5": mode => 644, ensure => file } }
    default: { file { "/tmp/existsfile5": mode => 711, ensure => file } }

}
