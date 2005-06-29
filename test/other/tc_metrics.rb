if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk/"
end

require 'puppet/metric'
require 'puppet'
require 'puppet/type'
require 'test/unit'

# $Id$

class TestMetric < Test::Unit::TestCase

    def gendata
        totalmax = 1000
        changemax = 1000
        eventmax = 10
        maxdiff = 10

        types = [Puppet::Type::File, Puppet::Type::Package, Puppet::Type::Service]
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
        Puppet[:rrddir] = File.join(Dir.getwd,"rrdtests")
        Puppet[:rrdgraph] = true
        Puppet[:loglevel] = :debug
    end

    def teardown
        system("rm -rf rrdtests")
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
