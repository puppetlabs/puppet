source :gemcutter

# We're making an assumption that you will have a recent Facter checked out in
# the parent directory. After 3.x is properly released, this should be changed
# back to pointing ata released version of Facter
gem 'facter', :path => '../facter'
gem 'rack', '1.2.2'


# NOTE: These groups are nothing but a little semantic sugar in the Gemfile,
# unless you explicitly exclude a group `bundle install` will install all gems
# across all groups

group :development do
  gem 'rake', :require => nil
  gem 'rspec', '~> 2.9.0'
  gem 'mocha', '~> 0.10.5'
  gem 'sqlite3', '~> 1.3.3'
  gem 'parallel_tests', '~> 0.8.4'
  # This is the /known/ version of RDoc which the "allfeatures" gemset on CI
  # runs, should be safe to pin it here
  #gem 'rdoc', '3.6.1'
end
