define testing {
    file { "/tmp/realize_defined_test1": ensure => file }
}
@testing { yay: }

define deeper {
    file { "/tmp/realize_defined_test2": ensure => file }
}

@deeper { boo: }

realize Testing[yay]
realize File["/tmp/realize_defined_test2"]
