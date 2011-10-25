begin
  require 'metric_fu'
  MetricFu::Configuration.run do |config|
    config.flay = { :dirs_to_flay => ['lib'] }
    config.rcov[:rcov_opts] << "-Ispec"
  end
rescue LoadError
  # Metric-fu not installed
  # http://metric-fu.rubyforge.org/
end
