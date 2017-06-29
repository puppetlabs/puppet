test_name "Bug #7165: Don't refresh service immediately after starting it"

tag 'audit:low',
    'audit:refactor', # Use block style `test_name`
    'audit:unit'     # testing basic service type behavior

confine :except, :platform => 'windows'

agents.each do |host|
  dir = host.tmpdir('7165-no-refresh')

manifest = %Q{
  file { "#{dir}/notify":
    content => "foo",
    notify  => Service["service"],
  }

  service { "service":
    ensure     => running,
    hasstatus  => true,
    hasrestart => true,
    status     => "test -e #{dir}/service",
    start      => "touch #{dir}/service",
    stop       => "rm -f #{dir}/service",
    restart    => "touch #{dir}/service_restarted",
    require    => File["#{dir}/notify"],
    provider   => base,
  }
}

  apply_manifest_on(host, manifest) do
    on(host, "test -e #{dir}/service")
    # service should not restart, since it wasn't running to begin with
    on(host, "test -e #{dir}/service_restarted", :acceptable_exit_codes => [1])
  end

  # will trigger a notify next time as the file changes
  on(host, "echo bar > #{dir}/notify")

  apply_manifest_on(host, manifest) do
    on(host, "test -e #{dir}/service")
    # service should restart this time
    on(host, "test -e #{dir}/service_restarted")
  end
end
