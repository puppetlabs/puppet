Puppet::Reports.register_report(:rrdgraph) do
  desc "Graph all available data about hosts using the RRD library.  You
    must have the Ruby RRDtool library installed to use this report, which
    you can get from
    [the RubyRRDTool RubyForge page](http://rubyforge.org/projects/rubyrrdtool/).
    This package may also be available as `librrd-ruby`, `ruby-rrd`, or `rrdtool-ruby` in your
    distribution's package management system.  The library and/or package will both
    require the binary `rrdtool` package from your distribution to be installed.

    This report will create, manage, and graph RRD database files for each
    of the metrics generated during transactions, and it will create a
    few simple html files to display the reporting host's graphs.  At this
    point, it will not create a common index file to display links to
    all hosts.

    All RRD files and graphs get created in the `rrddir` directory.  If
    you want to serve these publicly, you should be able to just alias that
    directory in a web server.

    If you really know what you're doing, you can tune the `rrdinterval`,
    which defaults to the `runinterval`."

  def hostdir
    @hostdir ||= File.join(Puppet[:rrddir], self.host)
  end

  def htmlfile(type, graphs, field)
    file = File.join(hostdir, "#{type}.html")
    File.open(file, "w") do |of|
      of.puts "<html><head><title>#{type.capitalize} graphs for #{host}</title></head><body>"

      graphs.each do |graph|
        if field == :first
          name = graph.sub(/-\w+.png/, '').capitalize
        else
          name = graph.sub(/\w+-/, '').sub(".png", '').capitalize
        end
        of.puts "<img src=#{graph}><br>"
      end
      of.puts "</body></html>"
    end

    file
  end

  def mkhtml
    images = Dir.entries(hostdir).find_all { |d| d =~ /\.png/ }

    periodorder = %w{daily weekly monthly yearly}

    periods = {}
    types = {}
    images.each do |n|
      type, period = n.sub(".png", '').split("-")
      periods[period] ||= []
      types[type] ||= []
      periods[period] << n
      types[type] << n
    end

    files = []
    # Make the period html files
    periodorder.each do |period|
      unless ary = periods[period]
        raise Puppet::Error, "Could not find graphs for #{period}"
      end
      files << htmlfile(period, ary, :first)
    end

    # make the type html files
    types.sort { |a,b| a[0] <=> b[0] }.each do |type, ary|
      newary = []
      periodorder.each do |period|
        if graph = ary.find { |g| g.include?("-#{period}.png") }
          newary << graph
        else
          raise "Could not find #{type}-#{period} graph"
        end
      end

      files << htmlfile(type, newary, :second)
    end

    File.open(File.join(hostdir, "index.html"), "w") do |of|
      of.puts "<html><head><title>Report graphs for #{host}</title></head><body>"
      files.each do |file|
        of.puts "<a href='#{File.basename(file)}'>#{File.basename(file).sub(".html",'').capitalize}</a><br/>"
      end
      of.puts "</body></html>"
    end
  end

  def process(time = nil)
    time ||= Time.now.to_i

    unless File.directory?(hostdir) and FileTest.writable?(hostdir)
      # Some hackishness to create the dir with all of the right modes and ownership
      config = Puppet::Settings.new
      config.define_settings(:reports, :hostdir => {:type => :directory, :default => hostdir, :owner => 'service', :mode => 0755, :group => 'service', :desc => "eh"})

      # This creates the dir.
      config.use(:reports)
    end

    self.metrics.each do |name, metric|
      metric.basedir = hostdir

      if name == "time"
        timeclean(metric)
      end

      metric.store(time)

      metric.graph
    end

    mkhtml unless Puppet::FileSystem.exist?(File.join(hostdir, "index.html"))
  end

  # Unfortunately, RRD does not deal well with changing lists of values,
  # so we have to pick a list of values and stick with it.  In this case,
  # that means we record the total time, the config time, and that's about
  # it.  We should probably send each type's time as a separate metric.
  def timeclean(metric)
    metric.values = metric.values.find_all { |name, label, value| ['total', 'config_retrieval'].include?(name.to_s) }
  end
end

