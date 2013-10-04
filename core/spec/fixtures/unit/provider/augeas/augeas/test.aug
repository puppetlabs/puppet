(*
Simple lens, written to be distributed with Puppet unit tests.

Author: Dominic Cleal <dcleal@redhat.com>

About: License:
  This file is licensed under the Apache 2.0 licence, like the rest of Puppet.
*)

module Test = autoload xfm
let lns = [ seq "line" . store /[^\n]+/ . del "\n" "\n" ]*
let filter = incl "/etc/test"
let xfm = transform lns filter
