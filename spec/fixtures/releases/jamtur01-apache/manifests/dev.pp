class apache::dev {
  include apache::params

  package{$apache::params::apache_dev: ensure => installed}
}
