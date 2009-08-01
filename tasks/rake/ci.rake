desc "Prep CI RSpec tests"
task :ci_prep do
    require 'rubygems'
    begin
        gem 'ci_reporter'
        require 'ci/reporter/rake/rspec'
        require 'ci/reporter/rake/test_unit'
        ENV['CI_REPORTS'] = 'results'
    rescue LoadError
       puts 'Missing ci_reporter gem. You must have the ci_reporter gem installed to run the CI spec tests'
    end 
end

desc "Run the CI RSpec tests"
task :ci_spec => [:ci_prep, 'ci:setup:rspec', :spec] do
    sh "exit 0"
end

desc "Run CI Unit tests"
task :ci_unit => [:ci_prep, 'ci:setup:testunit'] do
    sh "cd test; rake test; exit 0"
end
