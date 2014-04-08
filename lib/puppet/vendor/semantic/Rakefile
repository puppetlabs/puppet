# RSpec tasks
begin
  require 'rspec/core/rake_task'

  # Create the 'spec' task
  RSpec::Core::RakeTask.new(:spec) do |task|
    task.rspec_opts = '--color'
  end

  namespace :spec do
    desc "Run the test suite and generate coverage metrics"
    task :coverage => [ :simplecov, :spec ]

    # Add test coverage to the 'spec' task.
    task :simplecov do
      ENV['COVERAGE'] = '1'
    end
  end

  task :default => :spec
rescue LoadError
  warn "[Warning]: Could not load `rspec`."
end

# YARD tasks
begin
  require 'yard'
  require 'yard/rake/yardoc_task'

  YARD::Rake::YardocTask.new(:doc) do |yardoc|
    yardoc.files = [ 'lib/**/*.rb', '-', '**/*.md' ]
  end
rescue LoadError
  warn "[Warning]: Could not load `yard`."
end

# Cane tasks
begin
  require 'cane/rake_task'

  Cane::RakeTask.new(:cane) do |cane|
    cane.add_threshold 'coverage/.last_run.json', :>=, 100
    cane.abc_max = 15
  end

  Rake::Task['cane'].prerequisites << Rake::Task['spec:coverage']
  Rake::Task[:default].clear_prerequisites
  task :default => :cane
rescue LoadError
  warn "[Warning]: Could not load `cane`."
end

# Gem tasks
begin
  require 'rubygems/tasks'

  task :gem => 'gem:build'
  task :validate => [ 'cane', 'doc', 'gem:validate' ]

  namespace :gem do
    Gem::Tasks.new(
      :tag => { :format => 'v%s' },
      :sign => { :checksum => true, :pgp => true },
      :build => { :tar => true }
    )
  end
rescue LoadError
  warn "[Warning]: Could not load `rubygems/tasks`."
end
