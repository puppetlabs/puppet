#!/usr/bin/env puppet --debug

user {
    "jmccune": provider => "netinfo", ensure => present;
}
