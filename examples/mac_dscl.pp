#!/usr/bin/env puppet --debug --verbose --trace
#
# Jeff McCune: I use this for developing and testing the directory service
#              provider.

User  { provider => "directoryservice" }
Group { provider => "directoryservice" }

user {
    "testgone":
        ensure => absent,
        uid => 550;
    "testhere":
        ensure => present,
        password => "foobar",
        shell => "/bin/bash",
        uid => 551;
}

group {
    "testgone":
        ensure => absent,
        gid => 550;
    "testhere":
        ensure => present,
        gid => 551;

}
