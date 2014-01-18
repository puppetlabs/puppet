# $Id$

$files = ["/tmp/iterationatest", "/tmp/iterationbtest"]

file { $files: making_sure => file, mode => 755 }

file { ["/tmp/iterationctest", "/tmp/iterationdtest"]:
    making_sure => file,
    mode => 755
}

file {
    ["/tmp/iterationetest", "/tmp/iterationftest"]: making_sure => file, mode => 755;
    ["/tmp/iterationgtest", "/tmp/iterationhtest"]: making_sure => file, mode => 755;
}
