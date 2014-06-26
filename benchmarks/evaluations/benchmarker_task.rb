# Helper class that is used by the Rake task generator.
# Currently only supports defining arguments that are passed to run
# (The rake task generator always passes :warm_up_runs as an Integer when profiling).
# Other benchmarks, and for regular runs that wants arguments must specified them
# as an Array of symbols.
#
class BenchmarkerTask
  def self.run_args
    [:detail]
  end
end