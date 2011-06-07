test_name "#7728: Don't log whits on resource failure"

manifest = %Q{
  class foo {
    exec { "test": command => "/usr/bin/false" }

    notify { "before": before  => Exec["test"] }
    notify { "after":  require => Exec["test"] }
  }

  include foo
}

apply_manifest_on(agents, manifest) do
  # Note: using strings in the match, because I want them regexp-escaped,
  # and the assertion code will do that automatically. --daniel 2011-06-07
  assert_match(Regexp.quote('notice: /Stage[main]/Foo/Notify[after]: Dependency Exec[test] has failures: true'), stdout, "the after dependency must be reported")
  assert_no_match(Regexp.quote('Class[Foo]'), stdout, 'the class should not be mentioned')
  assert_no_match(Regexp.quote('Stage[Main]'), stdout, 'the class should not be mentioned')
end
