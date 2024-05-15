# @summary Manage /tmp/ntp.conf file
#
# Given an array of ntpservers, manage the /tmp/ntp.conf file
#
# @example
#   include ntp::config
#
# @param ntpservers
#   An array of ntpserver(s) that should be present in the conf file
class ntp::config(
  Array[String[1], 1] $ntpservers = undef,
) {

  file { '/tmp/ntp.conf':
    content => epp('ntp/ntp.conf.epp')
  }

}
