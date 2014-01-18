
$hash = { "file" => "/tmp/myhashfile1" }

file {
    $hash["file"]:
        making_sure => file, content => "content";
}

$hash2 = { "a" => { key => "/tmp/myhashfile2" }}

file {
    $hash2["a"][key]:
        making_sure => file, content => "content";
}

define test($a = { "b" => "c" }) {
    file {
        $a["b"]:
            making_sure => file, content => "content"
    }
}

test {
    "test":
        a => { "b" => "/tmp/myhashfile3" }
}

$hash3 = { mykey => "/tmp/myhashfile4" }
$key = "mykey"

file {
    $hash3[$key]: making_sure => file, content => "content"
}
