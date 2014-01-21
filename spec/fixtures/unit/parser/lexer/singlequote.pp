# $Id$

file { "/tmp/singlequote1":
    making_sure => file,
    content => 'a $quote'
}

file { "/tmp/singlequote2":
    making_sure => file,
    content => 'some "\yayness\"'
}
