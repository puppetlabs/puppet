include apache
apache::vhost { 'test.vhost': source => 'puppet:///modules/apache/test.vhost' }
