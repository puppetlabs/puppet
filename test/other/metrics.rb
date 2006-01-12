if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet/metric'
require 'puppet'
require 'puppet/type'
require 'test/unit'

$haverrd = true
begin
    require 'RRD'
rescue LoadError
    $haverrd = false
end

if $haverrd
    class TestMetric < Test::Unit::TestCase
        include TestPuppet

        def gendata
            totalmax = 1000
            changemax = 1000
            eventmax = 10
            maxdiff = 10

            types = [Puppet.type(:file), Puppet.type(:package), Puppet.type(:package)]
            data = [:total, :managed, :outofsync, :changed, :totalchanges]
            events = [:file_changed, :package_installed, :service_started]

            # if this is the first set of data points...
            typedata = Hash.new { |typehash,type|
                typehash[type] = Hash.new(0)
            }
            eventdata = Hash.new(0)
            types.each { |type|
                name = type.name
                typedata[type] = {}
                typedata[type][:total] = rand(totalmax)
                typedata[type][:managed] = rand(typedata[type][:total])
                typedata[type][:outofsync] = rand(typedata[type][:managed])
                typedata[type][:changed] = rand(typedata[type][:outofsync])
                typedata[type][:totalchanges] = rand(changemax)
            }

            events.each { |event|
                eventdata[event] = rand(eventmax)
            }

            return [typedata,eventdata]
        end

        def setup
            super
            Puppet[:rrdgraph] = true
        end

        def test_fakedata
            assert_nothing_raised { Puppet::Metric.init }
            time = Time.now.to_i
            start = time
            10.times {
                assert_nothing_raised { Puppet::Metric.load(gendata) }
                assert_nothing_raised { Puppet::Metric.tally }
                assert_nothing_raised { Puppet::Metric.store(time) }
                assert_nothing_raised { Puppet::Metric.clear }
                time += 300
            }
            assert_nothing_raised { Puppet::Metric.load(gendata) }
            assert_nothing_raised { Puppet::Metric.tally }
            assert_nothing_raised { Puppet::Metric.store(time) }
            assert_nothing_raised { Puppet::Metric.graph([start,time]) }

            File.open(File.join(Puppet[:rrddir],"index.html"),"w") { |of|
                of.puts "<html><body>"
                Puppet::Metric.each { |metric|
                    of.puts "<img src=%s.png><br>" % metric.name
                }
            }
        end
    end
else
    $stderr.puts "Missing RRD library -- skipping metric tests"
end

# $Id$
