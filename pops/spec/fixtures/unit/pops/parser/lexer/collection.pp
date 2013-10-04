class one {
    @file { "/tmp/colltest1": content => "one" }
    @file { "/tmp/colltest2": content => "two" }
}

class two {
    File <| content == "one" |>
}

include one, two
