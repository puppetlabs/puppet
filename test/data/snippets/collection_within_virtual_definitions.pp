define test($name) {
    file {"/tmp/collection_within_virtual_definitions1_$name.txt":
        content => "File name $name\n"
    }
    Test2 <||>
}

define test2() {
    file {"/tmp/collection_within_virtual_definitions2_$name.txt":
        content => "This is a test\n"
    }
}

node default {
    @test {"foo":
        name => "foo"
    }
    @test2 {"foo2": }
    Test <||>
}
