source :rubygems

def location_for(place)
  if place =~ /^(git:[^#]*)#(.*)/
    [{ :git => $1, :branch => $2, :require => false }]
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

group(:development, :test) do
  gem "puppet", *location_for('file://.')
  gem "facter", *location_for(ENV['FACTER_LOCATION'] || '~> 1.6')
  gem "hiera", *location_for(ENV['HIERA_LOCATION'] || '~> 1.0')
  gem "rack", "~> 1.4", :require => false
  gem "rake", :require => false
  gem "rspec", "~> 2.11.0", :require => false
  gem "mocha", "~> 0.10.5", :require => false
  gem "activerecord", *location_for('~> 3.0.7')
  gem "couchrest", *location_for('~> 1.0')
  gem "net-ssh", *location_for('~> 2.1')
  gem "puppetlabs_spec_helper"
  gem "sqlite3"
  gem "stomp"
  gem "tzinfo"
end

platforms :mswin, :mingw do
  gem "sys-admin", "~> 1.5.6", :require => false
  gem "win32-api", "~> 1.4.8", :require => false
  gem "win32-dir", "~> 0.3.7", :require => false
  gem "win32-eventlog", "~> 0.5.3", :require => false
  gem "win32-process", "~> 0.6.5", :require => false
  gem "win32-security", "~> 0.1.4", :require => false
  gem "win32-service", "~> 0.7.2", :require => false
  gem "win32-taskscheduler", "~> 0.2.2", :require => false
  gem "win32console", "~> 1.3.2", :require => false
  gem "windows-api", "~> 0.4.1", :require => false
  gem "windows-pr", "~> 1.2.1", :require => false
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:filetype=ruby
