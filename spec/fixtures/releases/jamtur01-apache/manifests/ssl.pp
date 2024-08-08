class apache::ssl {
  include apache


  case $facts['os']['name'] {
     "centos": {
        package { $apache::params::ssl_package:
           require => Package['httpd'],
        }
     }
     "ubuntu": {
        a2mod { "ssl": ensure => present, }
     }
  }
}
