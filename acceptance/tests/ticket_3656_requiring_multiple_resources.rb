test_name "#3656: requiring multiple resources"

tag 'audit:high',    # basic language functionality
    'audit:refactor', # Use block style `test_name`
    'audit:unit'

apply_manifest_on agents, %q{
    notify { 'foo': }
    notify { 'bar': }
    notify { 'baz':
      require => [Notify['foo'], Notify['bar']],
    }
}
