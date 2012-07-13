# Determine if we are running on JRuby or some other Ruby.
Puppet.features.add(:jruby) do
  defined?(RUBY_ENGINE) and RUBY_ENGINE == 'jruby'
end
