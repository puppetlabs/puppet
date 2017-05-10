test_name "yumrepo smoke test"
confine :to, :platform => [ "el", "centos", "fedora", "debian", "oracle", "redhat", "scientific" ]

agents.each do |agent|
  teardown do
    on(agent, puppet('resource yumrepo repo-1 ensure=absent'))
    on(agent, puppet('resource yumrepo repo-2 ensure=absent'))
    on(agent, puppet('resource yumrepo repo-3 ensure=absent'))
  end

  pp = <<-EOS
  file { '/etc/yum.repos.d' :
    ensure => 'directory',
  }
  yumrepo { 'repo-1' :
    descr    => 'PL repo for puppet',
    baseurl  => 'http://yum.puppetlabs.com/el',
    enabled  => '1',
    gpgcheck => '0',
    require => File['/etc/yum.repos.d'],
    ensure => 'present',
  }
  yumrepo { 'repo-2' :
    descr    => 'This repository does not exist',
    baseurl  => 'http://www.example.com',
    enabled  => '1',
    gpgcheck => '1',
    require => File['/etc/yum.repos.d'],
    ensure => 'present',
  }
  yumrepo { 'repo-3' :
    require => File['/etc/yum.repos.d'],
    ensure => 'absent',
  }
  EOS

  apply_manifest_on(agent, pp)
  on(agent, puppet('resource yumrepo')) do |res|
    assert_match(/repo-1/, res.stdout, "yumrepo repo-1 not created on #{agent}")
    assert_match(/repo-2/, res.stdout, "yumrepo repo-2 not created on #{agent}")
    fail_test("repo-3 created on #{agent}") if res.stdout.include? 'repo-3'
  end
end
