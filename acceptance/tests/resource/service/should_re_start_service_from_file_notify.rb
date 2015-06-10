test_name 'should check status and (re)start Service if notify File updated'

agents.each do |agent|
  tmpdir = create_tmpdir_for_user(agent, File.basename(__FILE__))

  manifest = <<-MANIFEST
  file{'#{tmpdir}/wut': ensure=>present,notify=>Service['MyFakeService']}
  service { 'MyFakeService':
    stop    => 'echo stop!      >> #{tmpdir}/testlog',
    start   => 'echo start!     >> #{tmpdir}/testlog',
    restart => 'echo restarted! >> #{tmpdir}/testlog',
    status  => '/bin/false',
    ensure  => running,
  }
  MANIFEST

  step 'Apply manifest'
  apply_manifest_on(agent, manifest, :catch_failures => true) do |result|
    assert_match(/ensure changed 'stopped' to 'running'/, result.stdout, 'did not start fake service')
  end
  step 'touch file'
  on(agent, "touch #{tmpdir}/wut")
  step 're-apply manifest, should (re)start service'
  apply_manifest_on(agent, manifest, :catch_failures => true) do |result|
    assert_match(/ensure changed 'stopped' to 'running'/, result.stdout, 'did not restart fake service')
  end
  on(agent, "cat #{tmpdir}/testlog") do |result|
    assert_match(/start!\nstart!\n/, result.stdout, 'did not use start attribute, or start twice')
  end
end
