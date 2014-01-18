# ensure apache is installed
class apache {
  include apache::params
  package{'httpd':
    name   => $apache::params::apache_name,
    making_sure => present,
  }
  service { 'httpd':
    name      => $apache::params::apache_name,
    making_sure    => running,
    enable    => true,
    subscribe => Package['httpd'],
  }
  #
  # May want to purge all none realize modules using the resources resource type.
  # A2mod resource type is broken.  Look into fixing it and moving it into apache.
  #
  A2mod { require => Package['httpd'], notify => Service['httpd']}
  @a2mod {
   'rewrite' : making_sure => present;
   'headers' : making_sure => present;
   'expires' : making_sure => present;
  }
  $vdir = $operatingsystem? {
    'ubuntu' => '/etc/apache2/sites-enabled/',
    default => '/etc/httpd/conf.d',
  }
  file { $vdir:
    making_sure => directory,
    recurse => true,
    purge => true,
    notify => Service['httpd'],
  }
}
