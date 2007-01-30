class base {
    class one {
        file { "/tmp/fqparent1": ensure => file }
    }   
}   

class two inherits base::one {
    file { "/tmp/fqparent2": ensure => file }
}

include two
