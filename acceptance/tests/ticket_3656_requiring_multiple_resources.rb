test_name "#3656: requiring multiple resources"
apply_manifest_on agents, %q{
    notify { 'foo': }
    notify { 'bar': }
    notify { 'baz':
      require => [Notify['foo'], Notify['bar']],
    }
}
