# included so we can test object types
require 'puppet'

module Puppet
    # A class for handling metrics.  This is currently ridiculously hackish.
	class Metric
        Puppet.config.setdefaults("metrics",
            :rrddir => {:default => "$vardir/rrd",
                :owner => "$user",
                :group => "$group",
                :desc => "The directory where RRD database files are stored."
            },
            :rrdgraph => [false, "Whether RRD information should be graphed."]
        )

        @@haverrd = false
        begin
            require 'RRD'
            @@haverrd = true
        rescue LoadError
        end

        def self.haverrd?
            @@haverrd
        end

        attr_accessor :type, :name, :value, :label

        def create
            Puppet.config.use(:metrics)

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
            @name = name.to_s

            if label
                @label = label
            else
                @label = name.to_s.capitalize.gsub("_", " ")
            end

            @values = []
        end

        def newvalue(name,value,label = nil)
            unless label
                label = name.to_s.capitalize.gsub("_", " ")
            end
            @values.push [name,label,value]
        end

        def path
            return File.join(Puppet[:rrddir],@name + ".rrd")
        end

        def graph(range = nil)
            unless @@haverrd
                Puppet.warning "RRD library is missing; cannot graph metrics"
                return
            end
            args = [self.path.sub(/rrd$/,"png")]

            args.push("--title",self.label)
            args.push("--imgformat","PNG")
            args.push("--interlace")
            colorstack = %w{#ff0000 #00ff00 #0000ff #099000 #000990 #f00990 #0f0f0f}
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
            unless @@haverrd
                Puppet.warning "RRD library is missing; cannot store metrics"
                return
            end
            unless FileTest.exists?(self.path)
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
                raise Puppet::Error, "Failed to update %s: %s" % [self.name,detail]
            end
        end
    end
end

# $Id$
