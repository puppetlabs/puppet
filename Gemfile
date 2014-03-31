source ENV['GEM_SOURCE'] || "https://rubygems.org"

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
  gem 'yard', :group => :development
  gem 'redcarpet', '~> 2.0', :group => :development
  gem "racc", "1.4.9", :group => :development

  # To enable the augeas feature, use this gem.
  # Note that it is a native gem, so the augeas headers/libs
  # are neeed.
  #gem 'ruby-augeas', :group => :development
end

gem "puppet", :path => File.dirname(__FILE__), :require => false
gem "facter", *location_for(ENV['FACTER_LOCATION'] || ['> 1.6', '< 3'])
gem "hiera", *location_for(ENV['HIERA_LOCATION'] || '~> 1.0')
gem "rake", "10.1.1", :require => false
gem "rgen", "0.6.5", :require => false

group(:development, :test) do

  # Jenkins workers may be using RSpec 2.9, so RSpec 2.11 syntax
  # (like `expect(value).to eq matcher`) should be avoided.
  gem "rspec", "~> 2.11.0", :require => false

  # Mocha is not compatible across minor version changes; because of this only
  # versions matching ~> 0.10.5 are supported. All other versions are unsupported
  # and can be expected to fail.
  gem "mocha", "~> 0.10.5", :require => false

  gem "yarjuf", "~> 1.0"

  # json-schema does not support windows, so omit it from the platforms list
  # json-schema uses multi_json, but chokes with multi_json 1.7.9, so prefer 1.7.7
  gem "multi_json", "1.7.7", :require => false, :platforms => [:ruby, :jruby]
  gem "json-schema", "2.1.1", :require => false, :platforms => [:ruby, :jruby]
end

group(:development) do
  case RUBY_VERSION
  when /^1.8/
    gem 'ruby-prof', "~> 0.13.1", :require => false
  else
    gem 'ruby-prof', :require => false
  end
end

group(:extra) do
  gem "rack", "~> 1.4", :require => false
  gem "activerecord", '~> 3.2', :require => false
  gem "couchrest", '~> 1.0', :require => false
  gem "net-ssh", '~> 2.1', :require => false
  gem "puppetlabs_spec_helper", :require => false
  gem "stomp", :require => false
  gem "tzinfo", :require => false
  case RUBY_PLATFORM
  when 'java'
    gem "jdbc-sqlite3", :require => false
    gem "msgpack-jruby", :require => false
  else
    gem "sqlite3", :require => false
    gem "msgpack", :require => false
  end
end

require 'yaml'
data = YAML.load_file(File.join(File.dirname(__FILE__), 'ext', 'project_data.yaml'))
bundle_platforms = data['bundle_platforms']
data['gem_platform_dependencies'].each_pair do |gem_platform, info|
  if bundle_deps = info['gem_runtime_dependencies']
    bundle_platform = bundle_platforms[gem_platform] or raise "Missing bundle_platform"
    platform(bundle_platform.intern) do
      bundle_deps.each_pair do |name, version|
        gem(name, version, :require => false)
      end
    end
  end
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:filetype=ruby
