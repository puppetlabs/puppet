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
      return 0
    end
  end

  def basedir
    if defined?(@basedir)
      @basedir
    else
      Puppet[:rrddir]
    end
  end

  def create(start = nil)
    Puppet.settings.use(:main, :metrics)

    start ||= Time.now.to_i - 5

    args = []

    if Puppet.features.rrd_legacy? && ! Puppet.features.rrd?
      @rrd = RRDtool.new(self.path)
    end

    values.each { |value|
      # the 7200 is the heartbeat -- this means that any data that isn't
      # more frequently than every two hours gets thrown away
      args.push "DS:#{value[0]}:GAUGE:7200:U:U"
    }
    args.push "RRA:AVERAGE:0.5:1:300"

    begin
      if Puppet.features.rrd_legacy? && ! Puppet.features.rrd?
        @rrd.create( Puppet[:rrdinterval].to_i, start, args)
      else
        RRD.create( self.path, '-s', Puppet[:rrdinterval].to_i.to_s, '-b', start.to_i.to_s, *args)
      end
    rescue => detail
      raise "Could not create RRD file #{path}: #{detail}"
    end
  end

  def dump
    if Puppet.features.rrd_legacy? && ! Puppet.features.rrd?
      puts @rrd.info
    else
      puts RRD.info(self.path)
    end
  end

  def graph(range = nil)
    unless Puppet.features.rrd? || Puppet.features.rrd_legacy?
      Puppet.warning "RRD library is missing; cannot graph metrics"
      return
    end

    unit = 60 * 60 * 24
    colorstack = %w{#00ff00 #ff0000 #0000ff #ffff00 #ff99ff #ff9966 #66ffff #990000 #099000 #000990 #f00990 #0f0f0f #555555 #333333 #ffffff}

    {:daily => unit, :weekly => unit * 7, :monthly => unit * 30, :yearly => unit * 365}.each do |name, time|
      file = self.path.sub(/\.rrd$/, "-#{name}.png")
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
        defs.push("DEF:#{value[0]}=#{self.path}:#{value[0]}:AVERAGE")
        lines.push("LINE2:#{value[0]}#{color}:#{value[1]}")
      }
      args << defs
      args << lines
      args.flatten!
      if range
        if Puppet.features.rrd_legacy? && ! Puppet.features.rrd?
          args.push("--start",range[0],"--end",range[1])
        else
          args.push("--start",range[0].to_i.to_s,"--end",range[1].to_i.to_s)
        end
      else
        if Puppet.features.rrd_legacy? && ! Puppet.features.rrd?
          args.push("--start", Time.now.to_i - time, "--end", Time.now.to_i)
        else
          args.push("--start", (Time.now.to_i - time).to_s, "--end", Time.now.to_i.to_s)
        end
      end

      begin
        #Puppet.warning "args = #{args}"
        if Puppet.features.rrd_legacy? && ! Puppet.features.rrd?
          RRDtool.graph( args )
        else
          RRD.graph( *args )
        end
      rescue => detail
        Puppet.err "Failed to graph #{self.name}: #{detail}"
      end
    end
  end

  def initialize(name,label = nil)
    @name = name.to_s

    @label = label || self.class.labelize(name)

    @values = []
  end

  def path
    File.join(self.basedir, @name + ".rrd")
  end

  def newvalue(name,value,label = nil)
    raise ArgumentError.new("metric name #{name.inspect} is not a string") unless name.is_a? String
    label ||= self.class.labelize(name)
    @values.push [name,label,value]
  end

  def store(time)
    unless Puppet.features.rrd? || Puppet.features.rrd_legacy?
      Puppet.warning "RRD library is missing; cannot store metrics"
      return
    end
    self.create(time - 5) unless FileTest.exists?(self.path)

    if Puppet.features.rrd_legacy? && ! Puppet.features.rrd?
      @rrd ||= RRDtool.new(self.path)
    end

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
      if Puppet.features.rrd_legacy? && ! Puppet.features.rrd?
        @rrd.update( template, [ arg ] )
      else
        RRD.update( self.path, '-t', template, arg )
      end
      #system("rrdtool updatev #{self.path} '#{arg}'")
    rescue => detail
      raise Puppet::Error, "Failed to update #{self.name}: #{detail}"
    end
  end

  def values
    @values.sort { |a, b| a[1] <=> b[1] }
  end

  # Convert a name into a label.
  def self.labelize(name)
    name.to_s.capitalize.gsub("_", " ")
  end
end

# This is necessary because we changed the class path in early 2007,
# and reports directly yaml-dump these metrics, so both client and server
# have to agree on the class name.
Puppet::Metric = Puppet::Util::Metric
