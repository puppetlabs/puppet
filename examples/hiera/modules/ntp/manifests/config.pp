# lookup ntpservers from hiera, or allow user of class to provide other value
class ntp::config($ntpservers = hiera('ntpservers')) {
  file{'/tmp/ntp.conf':
    content => template('ntp/ntp.conf.erb')
  }
}
