# $Id$

tag testing
tag(funtest)

define tagdefine {
    $path = tagged(tagdefine) ? {
        true => "true", false => "false"
    }

    file { "/tmp/taggeddefine$path": ensure => file }
}

tagdefine {}

$yayness = tagged(yayness) ? {
    true => "true", false => "false"
}

$testing = tagged(testing) ? {
    true => "true", false => "false"
}

$both = tagged(testing, yayness) ? {
    true => "true", false => "false"
}

$bothtrue = tagged(testing, testing) ? {
    true => "true", false => "false"
}

file { "/tmp/taggedyayness$yayness": ensure => file }
file { "/tmp/taggedtesting$testing": ensure => file }
file { "/tmp/taggedboth$both": ensure => file }
file { "/tmp/taggedbothtrue$bothtrue": ensure => file }
