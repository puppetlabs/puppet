# $Id$

tag testing
tag(funtest)

class tagdefine {
    $path = tagged(tagdefine) ? {
        true => "true", false => "false"
    }

    file { "/tmp/taggeddefine$path": making_sure => file }
}

include tagdefine

$yayness = tagged(yayness) ? {
    true => "true", false => "false"
}

$funtest = tagged(testing) ? {
    true => "true", false => "false"
}

$both = tagged(testing, yayness) ? {
    true => "true", false => "false"
}

$bothtrue = tagged(testing, testing) ? {
    true => "true", false => "false"
}

file { "/tmp/taggedyayness$yayness": making_sure => file }
file { "/tmp/taggedtesting$funtest": making_sure => file }
file { "/tmp/taggedboth$both": making_sure => file }
file { "/tmp/taggedbothtrue$bothtrue": making_sure => file }
