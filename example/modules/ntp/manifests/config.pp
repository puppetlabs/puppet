class ntp::config($ntpservers = hiera("ntpservers")) {
  file{"/tmp/ntp.conf":
    content => template("ntp/ntp.conf.erb")
  }
}
