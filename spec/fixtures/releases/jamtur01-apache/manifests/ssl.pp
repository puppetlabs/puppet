class apache::ssl {
  include apache


  case $operatingsystem {
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
