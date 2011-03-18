class one {
    @file { "/tmp/virtualtest1": content => "one" }
    @file { "/tmp/virtualtest2": content => "two" }
    @file { "/tmp/virtualtest3": content => "three" }
    @file { "/tmp/virtualtest4": content => "four" }
}

class two {
    File <| content == "one" |>
    realize File["/tmp/virtualtest2"]
    realize(File["/tmp/virtualtest3"], File["/tmp/virtualtest4"])
}

include one, two
