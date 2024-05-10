class ntp::config(
  Array[String[1], 1] $ntpservers = undef,
) {

  file { '/tmp/ntp.conf':
    content => epp('ntp/ntp.conf.epp')
  }

}
