Puppet::Parser::Functions::newfunction(
:select,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  The 'select' function has been renamed to 'filter'. Please update your manifests.

  The select function is reserved for future use.
  - Removed as of 3.4
  - requires `parser = future`.
  ENDHEREDOC

  raise NotImplementedError,
    "The 'select' function has been renamed to 'filter'. Please update your manifests."
end