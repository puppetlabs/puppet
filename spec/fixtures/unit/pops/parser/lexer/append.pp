$var=['/tmp/file1','/tmp/file2']

class arraytest {
    $var += ['/tmp/file3', '/tmp/file4']
    file {
        $var:
            content => "test"
    }
}

include arraytest
