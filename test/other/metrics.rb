#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet/metric'
require 'puppet'
require 'puppettest'
require 'puppet/type'

$haverrd = true
begin
    require 'RRD'
rescue LoadError
    $haverrd = false
end

if $haverrd
    class TestMetric < Test::Unit::TestCase
        include PuppetTest

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
            typedata = {}
            typedata[:total] = rand(totalmax)
            typedata[:managed] = rand(typedata[:total])
            typedata[:outofsync] = rand(typedata[:managed])
            typedata[:changed] = rand(typedata[:outofsync])
            typedata[:totalchanges] = rand(changemax)

            events.each { |event|
                eventdata[event] = rand(eventmax)
            }

            return {:typedata => typedata, :eventdata => eventdata}
        end

        def rundata(report, time)
            assert_nothing_raised {
                gendata.each do |name, data|
                    report.newmetric(name, data)
                end
                report.metrics.each { |n, m| m.store(time) }
            }
        end

        def setup
            super
            Puppet[:rrdgraph] = true
        end

        def test_fakedata
            report = Puppet::Transaction::Report.new
            time = Time.now.to_i
            start = time
            10.times {
                rundata(report, time)
                time += 300
            }
            rundata(report, time)

            report.metrics.each do |n, m| m.graph end

            File.open(File.join(Puppet[:rrddir],"index.html"),"w") { |of|
                of.puts "<html><body>"
                report.metrics.each { |name, metric|
                    of.puts "<img src=%s.png><br>" % metric.name
                }
            }
        end
    end
else
    $stderr.puts "Missing RRD library -- skipping metric tests"
end

# $Id$
