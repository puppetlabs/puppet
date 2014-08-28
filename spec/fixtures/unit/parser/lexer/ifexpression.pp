$one = 1
$two = 2

if ($one < $two) and (($two < 3) or ($two == 2)) {
    notice("True!")
}

if "test regex" =~ /(.*) regex/ {
    file {
        "/tmp/${1}iftest": ensure => file, mode => '0755'
    }
}
