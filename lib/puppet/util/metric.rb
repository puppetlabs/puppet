# included so we can test object types
require 'puppet'

# A class for handling metrics.  This is currently ridiculously hackish.
class Puppet::Util::Metric

    attr_accessor :type, :name, :value, :label
    attr_writer :values

    attr_writer :basedir

    # Return a specific value
    def [](name)
        if value = @values.find { |v| v[0] == name }
            return value[2]
        else
            return nil
        end
    end

    def basedir
        if defined? @basedir
            @basedir
        else
            Puppet[:rrddir]
        end
    end

    def create(start = nil)
        Puppet.settings.use(:main, :metrics)

        start ||= Time.now.to_i - 5

        @rrd = RRDtool.new(self.path)
        args = []

        values.each { |value|
            # the 7200 is the heartbeat -- this means that any data that isn't
            # more frequently than every two hours gets thrown away
            args.push "DS:%s:GAUGE:7200:U:U" % [value[0]]
        }
        args.push "RRA:AVERAGE:0.5:1:300"

        begin
            @rrd.create( Puppet[:rrdinterval].to_i, start, args)
        rescue => detail
            raise "Could not create RRD file %s: %s" % [path,detail]
        end
    end

    def dump
        puts @rrd.info
    end

    def graph(range = nil)
        unless Puppet.features.rrd?
            Puppet.warning "RRD library is missing; cannot graph metrics"
            return
        end

        unit = 60 * 60 * 24
        colorstack = %w{#00ff00 #ff0000 #0000ff #ffff00 #ff99ff #ff9966 #66ffff #990000 #099000 #000990 #f00990 #0f0f0f #555555 #333333 #ffffff}

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
                #Puppet.warning "args = #{args}"
                RRDtool.graph( args )
            rescue => detail
                Puppet.err "Failed to graph %s: %s" % [self.name,detail]
            end
        end
    end

    def initialize(name,label = nil)
        @name = name.to_s

        @label = label || labelize(name)

        @values = []
    end

    def path
        return File.join(self.basedir, @name + ".rrd")
    end

    def newvalue(name,value,label = nil)
        label ||= labelize(name)
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

        @rrd ||= RRDtool.new(self.path)

        # XXX this is not terribly error-resistant
        args = [time]
        temps = []
        values.each { |value|
            #Puppet.warning "value[0]: #{value[0]}; value[1]: #{value[1]}; value[2]: #{value[2]}; "
            args.push value[2]
            temps.push value[0]
        }
        arg = args.join(":")
        template = temps.join(":")
        begin
            @rrd.update( template, [ arg ] )
            #system("rrdtool updatev %s '%s'" % [self.path, arg])
        rescue => detail
            raise Puppet::Error, "Failed to update %s: %s" % [self.name,detail]
        end
    end

    def values
        @values.sort { |a, b| a[1] <=> b[1] }
    end

    private

    # Convert a name into a label.
    def labelize(name)
        name.to_s.capitalize.gsub("_", " ")
    end
end

# This is necessary because we changed the class path in early 2007,
# and reports directly yaml-dump these metrics, so both client and server
# have to agree on the class name.
Puppet::Metric = Puppet::Util::Metric
