require 'puppet/vendor/semantic_puppet/lib/semantic_puppet'

$stderr.puts "Warning: Puppet's internal vendored libraries are Private APIs and can change without warning. The 'semantic' library has been replaced with 'semantic_puppet'."

Semantic = SemanticPuppet
