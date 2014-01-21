# $Id$

$var = "value"

case $var {
  "nope": {
     file { "/tmp/fakefile": mode => 644, making_sure => file }
  }
  "value": {
     file { "/tmp/existsfile": mode => 755, making_sure => file }
  }
}

$ovar = "yayness"

case $ovar {
    "fooness": {
         file { "/tmp/nostillexistsfile": mode => 644, making_sure => file }
    }
    "booness", "yayness": {
        case $var {
            "nep": {
                 file { "/tmp/noexistsfile": mode => 644, making_sure => file }
            }
            "value": {
                 file { "/tmp/existsfile2": mode => 755, making_sure => file }
            }
        }
    }
}

case $ovar {
    "fooness": {
         file { "/tmp/nostillexistsfile": mode => 644, making_sure => file }
    }
    default: {
        file { "/tmp/existsfile3": mode => 755, making_sure => file }
    }
}

$bool = true

case $bool {
    true: {
        file { "/tmp/existsfile4": mode => 755, making_sure => file }
    }
}

$yay = yay
$a = yay
$b = boo

case $yay {
    $a: { file { "/tmp/existsfile5": mode => 755, making_sure => file } }
    $b: { file { "/tmp/existsfile5": mode => 644, making_sure => file } }
    default: { file { "/tmp/existsfile5": mode => 711, making_sure => file } }

}

$regexvar = "exists regex"
case $regexvar {
    "no match": { file { "/tmp/existsfile6": mode => 644, making_sure => file } }
    /(.*) regex$/: { file { "/tmp/${1}file6": mode => 755, making_sure => file } }
    default: { file { "/tmp/existsfile6": mode => 711, making_sure => file } }
}
