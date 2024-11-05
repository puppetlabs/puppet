define apache::vhost( $port, $docroot, $ssl=true, $template='apache/vhost-default.conf.erb', $priority, $serveraliases = '' ) {
  include apache
  $vdir = $os['name']? {
    'ubuntu' => '/etc/apache2/sites-enabled/',
    default => '/etc/httpd/conf.d',
  }
  file{"${vdir}/${priority}-${name}":
    content => template($template),
    owner => 'root',
    group => 'root',
    mode => '0777',
    require => Package['httpd'],
    notify => Service['httpd'],
  }
}
