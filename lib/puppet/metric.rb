#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'puppet'

module Puppet
	class Metric
        def Metric.init
            @@typemetrics = Hash.new { |typehash,type|
                typehash[type] = Hash.new(0)
            }

            @@eventmetrics = Hash.new(0)

            @@metrics = {}
        end

        def Metric.clear
            Metric.init
        end

        def Metric.gather
            Metric.init

            # first gather stats about all of the types
            Puppet::Type.eachtype { |type|
                type.each { |instance|
                    @@typemetrics[type][:total] += 1
                    if instance.managed?
                        @@typemetrics[type][:managed] += 1
                    end
                }
            }

            # the rest of the metrics are injected directly by type.rb
        end

        def Metric.add(type,instance,metric,count)
            return unless defined? @@typemetrics
            case metric
            when :outofsync:
                @@typemetrics[type][metric] += count
            when :changes:
                @@typemetrics[type][:changed] += 1
                @@typemetrics[type][:totalchanges] += count
            else
                raise "Unknown metric %s" % metric
            end
        end

        # we're currently throwing away the type and instance information
        def Metric.addevents(type,instance,events)
            return unless defined? @@eventmetrics
            events.each { |event|
                @@eventmetrics[event] += 1
            }
        end

        def Metric.each
            @@metrics.each { |name,metric|
                yield metric
            }
        end

        def Metric.load(ary)
            @@typemetrics = ary[0]
            @@eventmetrics = ary[1]
        end

        def Metric.graph(range = nil)
            @@metrics.each { |name,metric|
                metric.graph(range)
            }
        end

        def Metric.store(time = nil)
            require 'RRD'
            unless time
                time = Time.now.to_i
            end
            @@metrics.each { |name,metric|
                metric.store(time)
            }
        end

        def Metric.tally
            type = Metric.new("typecount","Types")
            type.newvalue("Number",@@typemetrics.length)

            metrics = {
                :total => "Instances",
                :managed => "Managed Instances",
                :outofsync => "Out of Sync Instances",
                :changed => "Changed Instances",
                :totalchanges => "Total Number of Changes",
            }
            total = Hash.new(0)
            @@typemetrics.each { |type,instancehash|
                name = type.name.to_s
                instmet = Metric.new("type-" + name,name.capitalize)
                metrics.each { |symbol,label|
                    instmet.newvalue(symbol.to_s,instancehash[symbol],label)
                    total[symbol] += instancehash[symbol]
                }
            }

            totalmet = Metric.new("typetotals","Type Totals")
            metrics.each { |symbol,label|
                totalmet.newvalue(symbol.to_s,total[symbol],label)
            }

            eventmet = Metric.new("events")
            total = 0
            @@eventmetrics.each { |event,count|
                event = event.to_s
                # add the specific event as a value, with the label being a
                # capitalized version with s/_/ /g
                eventmet.newvalue(
                    event,
                    count,
                    event.capitalize.gsub(/_/,' ')
                )

                total += count
            }
            eventmet.newvalue("total",total,"Event Total")
        end

        attr_accessor :type, :name, :value, :label


        def create
            dir = Puppet[:rrddir]
            unless dir
                raise "Cannot store metrics unless RRDDir is set"
            end

            unless FileTest.exist?(dir)
                tmp = dir.sub(/^\//,'')
                path = [File::SEPARATOR]
                tmp.split(File::SEPARATOR).each { |d|
                    path.push d
                    unless FileTest.exist?(File.join(path))
                        Dir.mkdir(File.join(path))
                    end
                }
            end

            unless FileTest.directory?(dir)
                raise Puppet::Error.new("%s must be a directory" % dir)
            end

            path = self.path
            args = [
                path,
                "--start", Time.now.to_i - 5,
                "--step", "300", # XXX Defaulting to every five minutes, but prob bad
            ]

            @values.each { |value|
                args.push "DS:%s:GAUGE:600:U:U" % value[0]
            }
            args.push "RRA:AVERAGE:0.5:1:300"

            begin
                RRD.create(*args)
            rescue => detail
                raise "Could not create RRD file %s: %s" % [path,detail]
            end
        end

        def initialize(name,label = nil)
            @name = name
            if label
                @label = label
            else
                @label = name.capitalize
            end

            @values = []
            if @@metrics.include?(self.name)
                raise "Somehow created two metrics with name %s" % self.name
            else
                @@metrics[self.name] = self
            end
        end

        def newvalue(name,value,label = nil)
            unless label
                label = name.capitalize
            end
            @values.push [name,label,value]
        end

        def path
            return File.join(Puppet[:rrddir],@name + ".rrd")
        end

        def graph(range = nil)
            args = [self.path.sub(/rrd$/,"png")]
            args.push("--title",self.label)
            args.push("--imgformat","PNG")
            args.push("--interlace")
            colorstack = %w{#ff0000 #00ff00 #0000ff #099000 #000990 #f00990}
            i = 0
            defs = []
            lines = []
            @values.zip(colorstack).each { |value,color|
                next if value.nil?
                # this actually uses the data label
                defs.push("DEF:%s=%s:%s:AVERAGE" % [value[0],self.path,value[0]])
                lines.push("LINE3:%s%s:%s" % [value[0],color,value[1]])
            }
            args << defs
            args << lines
            args.flatten!
            if range 
                args.push("--start",range[0],"--end",range[1])
            end

            begin
                RRD.graph(*args)
            rescue => detail
                Puppet.err "Failed to graph %s: %s" % [self.name,detail]
            end
        end

        def store(time)
            unless FileTest.exists?(File.join(Puppet[:rrddir],@name + ".rrd"))
                self.create
            end

            # XXX this is not terribly error-resistant
            args = [time]
            @values.each { |value|
                args.push value[2]
            }
            arg = args.join(":")
            begin
                RRD.update(self.path,args.join(":"))
            rescue => detail
                Puppet.err "Failed to update %s: %s" % [self.name,detail]
            end
        end
    end
end
