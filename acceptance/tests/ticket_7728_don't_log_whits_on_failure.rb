test_name "#7728: Don't log whits on resource failure"

manifest = %Q{
  class foo {
    exec { "test": command => "false", path => ['/bin', '/usr/bin'] }

    notify { "before": before  => Exec["test"] }
    notify { "after":  require => Exec["test"] }
  }

  include foo
}

apply_manifest_on(agents, manifest) do
  assert_match(Regexp.new(Regexp.quote('/Stage[main]/Foo/Notify[after]: Dependency Exec[test] has failures: true')), stdout, "the after dependency must be reported")
  assert_no_match(Regexp.new(Regexp.quote('Class[Foo]')), stdout, 'the class should not be mentioned')
  assert_no_match(Regexp.new(Regexp.quote('Stage[Main]')), stdout, 'the class should not be mentioned')
end
