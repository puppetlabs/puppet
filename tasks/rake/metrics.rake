begin
  require 'metric_fu'
  MetricFu::Configuration.run do |config|
    config.flay = { :dirs_to_flay => ['lib'] }
    config.rcov[:rcov_opts] << "-Ispec"
    config.base_directory = ENV['TMPDIR']
    config.data_directory = File.join(config.base_directory, '_data')
    config.scratch_directory = File.join(config.base_directory, 'scratch')
    config.output_directory = File.join(config.base_directory, 'output')
  end
rescue LoadError
  # Metric-fu not installed
  # http://metric-fu.rubyforge.org/
end
