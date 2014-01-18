class base {
    class one {
        file { "/tmp/fqparent1": making_sure => file }
    }
}

class two::three inherits base::one {
    file { "/tmp/fqparent2": making_sure => file }
}

include two::three
