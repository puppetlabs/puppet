source ENV['GEM_SOURCE'] || "https://rubygems.org"

gemspec

def location_for(place, fake_version = nil)
  if place =~ /^(git[:@][^#]*)#(.*)/
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

# C Ruby (MRI) or Rubinius, but NOT Windows
platforms :ruby do
  gem 'pry', :group => :development
  gem 'redcarpet', '~> 2.0', :group => :development
  gem "racc", "1.4.9", :group => :development

  # To enable the augeas feature, use this gem.
  # Note that it is a native gem, so the augeas headers/libs
  # are neeed.
  #gem 'ruby-augeas', :group => :development
end

# override .gemspec deps - may issue warning depending on Bundler version
gem "facter", *location_for(ENV['FACTER_LOCATION']) if ENV.has_key?('FACTER_LOCATION')
gem "hiera", *location_for(ENV['HIERA_LOCATION']) if ENV.has_key?('HIERA_LOCATION')
# PUP-7115 - return to a gem dependency in Puppet 5
# gem "semantic_puppet", *location_for(ENV['SEMANTIC_PUPPET_LOCATION'] || ['>= 0.1.3', '< 2'])

group(:development, :test) do
  # rake is in .gemspec as a development dependency but cannot
  # be removed here *yet* due to TravisCI / AppVeyor which call:
  # bundle install --without development
  # PUP-7433 describes work necessary to restructure this
  gem "rake", "10.1.1", :require => false
  gem "rspec", "~> 3.1", :require => false
  gem "rspec-its", "~> 1.1", :require => false
  gem "rspec-collection_matchers", "~> 1.1", :require => false
  gem "rspec-legacy_formatters", "~> 1.0", :require => false

  # Mocha is not compatible across minor version changes; because of this only
  # versions matching ~> 0.10.5 are supported. All other versions are unsupported
  # and can be expected to fail.
  gem "mocha", '~> 1.5.0', :require => false

  gem "yarjuf", "~> 2.0"

  # json-schema does not support windows, so omit it from the platforms list
  gem "json-schema", "~> 2.0", :require => false, :platforms => [:ruby, :jruby]

  if RUBY_VERSION >= '2.0'
    # pin rubocop as 0.50 requires a higher version of the rainbow gem (see below)
    gem 'rubocop', '~> 0.49.1', :platforms => [:ruby]
    gem 'rubocop-i18n', '~> 1.2.0', :platforms => [:ruby]
  end

  # pin rainbow gem as 2.2.1 requires rubygems 2.6.9+ and (donotwant)
  gem "rainbow", "< 2.2.1", :platforms => [:ruby]

  gem 'rdoc', "~> 4.1", :platforms => [:ruby]
  gem 'yard'

  # ronn is used for generating manpages.
  gem 'ronn', '~> 0.7.3', :platforms => [:ruby]

  gem 'webmock', '~> 1.24'
  gem 'vcr', '~> 2.9'
  gem "hiera-eyaml", :require => false

  gem 'memory_profiler', :platforms => [:mri_21, :mri_22, :mri_23, :mri_24, :mri_25]
end

group(:development) do
  if RUBY_PLATFORM != 'java'
    gem 'ruby-prof', '>= 0.16.0', :require => false
  end

  gem 'gettext-setup', '~> 0.28', :require => false
end

group(:extra) do
  gem "rack", "~> 1.4", :require => false
  gem "puppetlabs_spec_helper", :require => false
  gem "msgpack", :require => false
end


if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:filetype=ruby
