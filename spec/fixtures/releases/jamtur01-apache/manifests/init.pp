# ensure apache is installed
class apache {
  include apache::params
  package{'httpd':
    name   => $apache::params::apache_name,
    ensure => present,
  }
  service { 'httpd':
    name      => $apache::params::apache_name,
    ensure    => running,
    enable    => true,
    subscribe => Package['httpd'],
  }
  if ($::operatingsystem == 'Fedora') and ($::operatingsystemmajrelease == '23') {
    package{'libnghttp2':
      ensure => latest,
      install_options => '--best',
      before => Package['httpd'],
    }
  }
  #
  # May want to purge all none realize modules using the resources resource type.
  # A2mod resource type is broken.  Look into fixing it and moving it into apache.
  #
  A2mod { require => Package['httpd'], notify => Service['httpd']}
  @a2mod {
   'rewrite' : ensure => present;
   'headers' : ensure => present;
   'expires' : ensure => present;
  }
  $vdir = $operatingsystem? {
    'ubuntu' => '/etc/apache2/sites-enabled/',
    default => '/etc/httpd/conf.d',
  }
  file { $vdir:
    ensure => directory,
    recurse => true,
    purge => true,
    notify => Service['httpd'],
  }
}
