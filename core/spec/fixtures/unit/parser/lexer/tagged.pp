# $Id$

tag testing
tag(funtest)

class tagdefine {
    $path = tagged(tagdefine) ? {
        true => "true", false => "false"
    }

    file { "/tmp/taggeddefine$path": ensure => file }
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

file { "/tmp/taggedyayness$yayness": ensure => file }
file { "/tmp/taggedtesting$funtest": ensure => file }
file { "/tmp/taggedboth$both": ensure => file }
file { "/tmp/taggedbothtrue$bothtrue": ensure => file }
