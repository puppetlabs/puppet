# $Id$

class base(mode) {
    file { "/tmp/classargtest1": create => true, mode => $mode }
}

class sub inherits base {
    file { "/tmp/classargtest2": create => true, mode => $mode }
}

sub { "testing": mode => 755 }
