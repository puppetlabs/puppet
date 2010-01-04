require 'benchmark'
module Puppet::Rails::Benchmark
    $benchmarks = {:accumulated => {}}

    def time_debug?
        Puppet::Rails::TIME_DEBUG
    end

    def railsmark(message)
        result = nil
        seconds = Benchmark.realtime { result = yield }
        Puppet.debug(message + " in %0.2f seconds" % seconds)

        $benchmarks[message] = seconds if time_debug?
        result
    end

    def debug_benchmark(message)
        unless Puppet::Rails::TIME_DEBUG
            return yield
        end

        railsmark(message) { yield }
    end

    # Collect partial benchmarks to be logged when they're
    # all done.
    #   These are always low-level debugging so we only
    # print them if time_debug is enabled.
    def accumulate_benchmark(message, label)
        unless time_debug?
            return yield
        end

        $benchmarks[:accumulated][message] ||= Hash.new(0)
        $benchmarks[:accumulated][message][label] += Benchmark.realtime { yield }
    end

    # Log the accumulated marks.
    def log_accumulated_marks(message)
        return unless time_debug?

        if $benchmarks[:accumulated].empty? or $benchmarks[:accumulated][message].nil? or $benchmarks[:accumulated][message].empty?
            return
        end

        $benchmarks[:accumulated][message].each do |label, value|
            Puppet.debug(message + ("(%s)" % label) + (" in %0.2f seconds" % value))
        end
    end

    def write_benchmarks
        return unless time_debug?

        branch = %x{git branch}.split("\n").find { |l| l =~ /^\*/ }.sub("* ", '')

        file = "/tmp/time_debugging.yaml"

        require 'yaml'

        if FileTest.exist?(file)
            data = YAML.load_file(file)
        else
            data = {}
        end
        data[branch] = $benchmarks
        Puppet::Util.secure_open(file, "w") { |f| f.print YAML.dump(data) }
    end
end
