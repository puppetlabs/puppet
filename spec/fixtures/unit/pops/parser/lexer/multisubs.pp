class base {
    file { "/tmp/multisubtest": content => "base", mode => 644 }
}

class sub1 inherits base {
    File["/tmp/multisubtest"] { mode => 755 }
}

class sub2 inherits base {
    File["/tmp/multisubtest"] { content => sub2 }
}

include sub1, sub2
