# Profiling Puppet

Puppet is a beast. Puppet is at times a very *slow* beast. Maybe we can find
what is making it slow and fix it.

## Coarse Grained Profiling

There is a built-in system of profiling that can be used to identify some slow
spots. This can only work with code that is explicitly instrumented, which, at
the time of this writing, is primarily the compiler. To enable profiling there
are several options:

* To profile every request on the master add `--profile` to your master's
  startup.
* To profile a single run for an agent add `--profile` to your agent's options
  for that run.
* To profile a masterless run add `--profile` to your `puppet apply` options.

The timing information will be output to the logs and tagged with the word
"PROFILE".

For the agent there is actually a second system: evaltrace. You can enable this
on the agent by passing it `--evaltrace`. Timing information for each resource
will be output to the logs.

## Using a Ruby Profiler

For much finer grained profiling, you'll want to use
[ruby-prof](https://rubygems.org/gems/ruby-prof). Once you have the gem
installed you can either modify the code to profile a certain section (using
RubyProf.profile) or run the master with ruby-prof by adding `use
Rack::RubyProf, :path => '/temp/profile'` to the config.ru for your master.

## Running the Benchmarks

Puppet has a number of benchmark scenarios to pinpoint problems in specific,
known, use cases. The benchmark scenarios live in the `benchmarks` directory.

To run a scenario you do:

    bundle exec rake benchmark:<scenario_name>

If you have ruby-prof installed you can get a calltrace of the benchmark
scenario by running:

    bundle exec rake benchmark:<scenario_name>:profile

The calltrace file is viewable with
[kcachegrind](http://kcachegrind.sourceforge.net/html/Home.html).
