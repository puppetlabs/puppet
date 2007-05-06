# included so we can test object types
require 'puppet'

# A class for handling metrics.  This is currently ridiculously hackish.
class Puppet::Util::Metric
    
    # Load the library as a feature, so we can test its presence.
    Puppet.features.add :rrd, :libs => 'RRD'

    attr_accessor :type, :name, :value, :label
    attr_writer :values

    attr_writer :basedir

    def basedir
        if defined? @basedir
            @basedir
        else
            Puppet[:rrddir]
        end
    end

    def create(start = nil)
        Puppet.config.use(:metrics)

        start ||= Time.now.to_i - 5

        path = self.path
        args = [
            path,
            "--start", start,
            "--step", Puppet[:rrdinterval]
        ]

        values.each { |value|
            # the 7200 is the heartbeat -- this means that any data that isn't
            # more frequently than every two hours gets thrown away
            args.push "DS:%s:GAUGE:7200:U:U" % [value[0]]
        }
        args.push "RRA:AVERAGE:0.5:1:300"

        begin
            RRD.create(*args)
        rescue => detail
            raise "Could not create RRD file %s: %s" % [path,detail]
        end
    end

    def dump
        puts RRD.info(self.path)
    end

    def graph(range = nil)
        unless Puppet.features.rrd?
            Puppet.warning "RRD library is missing; cannot graph metrics"
            return
        end

        unit = 60 * 60 * 24
        colorstack = %w{#ff0000 #00ff00 #0000ff #099000 #000990 #f00990 #0f0f0f}

        {:daily => unit, :weekly => unit * 7, :monthly => unit * 30, :yearly => unit * 365}.each do |name, time|
            file = self.path.sub(/\.rrd$/, "-%s.png" % name)
            args = [file]

            args.push("--title",self.label)
            args.push("--imgformat","PNG")
            args.push("--interlace")
            i = 0
            defs = []
            lines = []
            #p @values.collect { |s,l| s }
            values.zip(colorstack).each { |value,color|
                next if value.nil?
                # this actually uses the data label
                defs.push("DEF:%s=%s:%s:AVERAGE" % [value[0],self.path,value[0]])
                lines.push("LINE2:%s%s:%s" % [value[0],color,value[1]])
            }
            args << defs
            args << lines
            args.flatten!
            if range 
                args.push("--start",range[0],"--end",range[1])
            else
                args.push("--start", Time.now.to_i - time, "--end", Time.now.to_i)
            end

            begin
                RRD.graph(*args)
            rescue => detail
                Puppet.err "Failed to graph %s: %s" % [self.name,detail]
            end
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

    def path
        return File.join(self.basedir, @name + ".rrd")
    end

    def newvalue(name,value,label = nil)
        unless label
            label = name.to_s.capitalize.gsub("_", " ")
        end
        @values.push [name,label,value]
    end

    def store(time)
        unless Puppet.features.rrd?
            Puppet.warning "RRD library is missing; cannot store metrics"
            return
        end
        unless FileTest.exists?(self.path)
            self.create(time - 5)
        end

        # XXX this is not terribly error-resistant
        args = [time]
        values.each { |value|
            args.push value[2]
        }
        arg = args.join(":")
        begin
            RRD.update(self.path,arg)
            #system("rrdtool updatev %s '%s'" % [self.path, arg])
        rescue => detail
            raise Puppet::Error, "Failed to update %s: %s" % [self.name,detail]
        end
    end

    def values
        @values.sort { |a, b| a[1] <=> b[1] }
    end
end

Puppet::Metric = Puppet::Util::Metric

# $Id$
