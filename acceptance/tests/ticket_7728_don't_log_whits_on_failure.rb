test_name "#7728: Don't log whits on resource failure"

tag 'audit:low',
    'audit:refactor', # Use block style `test_name`
    'audit:unit'

manifest = %Q{
  class foo {
    exec { "test": command => "false", path => ['/bin', '/usr/bin'] }

    notify { "before": before  => Exec["test"] }
    notify { "after":  require => Exec["test"] }
  }

  include foo
}

agents.each do |agent|
  next if agent['locale'] == 'ja'

  apply_manifest_on(agent, manifest) do
    assert_match(Regexp.new(Regexp.quote('/Stage[main]/Foo/Notify[after]: Dependency Exec[test] has failures: true')), stdout, "the after dependency must be reported")
    assert_no_match(Regexp.new(Regexp.quote('Class[Foo]: Dependency Exec[test] has failures: true')), stdout, 'the class should not be mentioned')
    assert_no_match(Regexp.new(Regexp.quote('Stage[main]: Dependency Exec[test] has failures: true')), stdout, 'the stage should not be mentioned')
  end
end
