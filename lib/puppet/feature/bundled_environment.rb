require 'puppet/util/feature'

Puppet.features.add(:bundled_environment) do
  if defined?(Bundler) && Bundler.respond_to?(:with_clean_env)
    true
  else
    false
  end

end

