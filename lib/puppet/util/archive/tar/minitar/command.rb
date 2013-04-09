#!/usr/bin/env ruby
# embed the code in puppet under the Puppet::Util namesapce
module Puppet
module Util

#--
# Archive::Tar::Baby 0.5.2
#   Copyright 2004 Mauricio Julio Ferna'ndez Pradier and Austin Ziegler
#   This is free software with ABSOLUTELY NO WARRANTY.
#
# This program is based on and incorporates parts of RPA::Package from
# rpa-base (lib/rpa/package.rb and lib/rpa/util.rb) by Mauricio and has been
# adapted to be more generic by Austin.
#
# This file contains an adaptation of Ruby/ProgressBar by Satoru
# Takabayashi <satoru@namazu.org>, copyright 2001 - 2004.
#
# It is licensed under the GNU General Public Licence or Ruby's licence.
#
# $Id$
#++

require 'zlib'

# TODO: add
# TODO: delete ???

require 'optparse'
require 'ostruct'
require 'fileutils'

module Archive::Tar::Minitar::Command
  class ProgressBar
    VERSION = "0.8"

    attr_accessor :total
    attr_accessor :title

    def initialize (title, total, out = STDERR)
      @title = title
      @total = total
      @out = out
      @bar_width = 80
      @bar_mark = "o"
      @current = 0
      @previous = 0
      @is_finished = false
      @start_time = Time.now
      @previous_time = @start_time
      @title_width = 14
      @format = "%-#{@title_width}s %3d%% %s %s"
      @format_arguments = [:title, :percentage, :bar, :stat]
      show
    end

  private
    def convert_bytes (bytes)
      if bytes < 1024
        sprintf("%6dB", bytes)
      elsif bytes < 1024 * 1000 # 1000kb
        sprintf("%5.1fKB", bytes.to_f / 1024)
      elsif bytes < 1024 * 1024 * 1000  # 1000mb
        sprintf("%5.1fMB", bytes.to_f / 1024 / 1024)
      else
        sprintf("%5.1fGB", bytes.to_f / 1024 / 1024 / 1024)
      end
    end

    def transfer_rate
      bytes_per_second = @current.to_f / (Time.now - @start_time)
      sprintf("%s/s", convert_bytes(bytes_per_second))
    end

    def bytes
      convert_bytes(@current)
    end

    def format_time (t)
      t = t.to_i
      sec = t % 60
      min  = (t / 60) % 60
      hour = t / 3600
      sprintf("%02d:%02d:%02d", hour, min, sec);
    end

    # ETA stands for Estimated Time of Arrival.
    def eta
      if @current == 0
        "ETA:  --:--:--"
      else
      elapsed = Time.now - @start_time
      eta = elapsed * @total / @current - elapsed;
      sprintf("ETA:  %s", format_time(eta))
      end
    end

    def elapsed
      elapsed = Time.now - @start_time
      sprintf("Time: %s", format_time(elapsed))
    end

    def stat
      if @is_finished then elapsed else eta end
    end

    def stat_for_file_transfer
      if @is_finished then 
        sprintf("%s %s %s", bytes, transfer_rate, elapsed)
      else 
        sprintf("%s %s %s", bytes, transfer_rate, eta)
      end
    end

    def eol
      if @is_finished then "\n" else "\r" end
    end

    def bar
      len = percentage * @bar_width / 100
      sprintf("|%s%s|", @bar_mark * len, " " *  (@bar_width - len))
    end

    def percentage(value = nil)
      if @total.zero?
        100
      else
        (value || @current) * 100 / @total
      end
    end

    def title
      @title[0,(@title_width - 1)] + ":"
    end

    def get_width
      # FIXME: I don't know how portable it is.
      default_width = 80
        #   begin
        #     tiocgwinsz = 0x5413
        #     data = [0, 0, 0, 0].pack("SSSS")
        #     if @out.ioctl(tiocgwinsz, data) >= 0 then
        #       rows, cols, xpixels, ypixels = data.unpack("SSSS")
        #       if cols >= 0 then cols else default_width end
        #     else
        #       default_width
        #     end
        #   rescue Exception
        #     default_width
        #   end
    end

    def show
      arguments = @format_arguments.map {|method| send(method) }
      line = sprintf(@format, *arguments)

      width = get_width
      if line.length == width - 1 
        @out.print(line + eol)
      elsif line.length >= width
        @bar_width = [@bar_width - (line.length - width + 1), 0].max
        if @bar_width == 0 then @out.print(line + eol) else show end
      else # line.length < width - 1
        @bar_width += width - line.length + 1
        show
      end
      @previous_time = Time.now
    end

    def show_progress
      if @total.zero?
        cur_percentage = 100
        prev_percentage = 0
      else
        cur_percentage  = (@current  * 100 / @total).to_i
        prev_percentage = (@previous * 100 / @total).to_i
      end

      if cur_percentage > prev_percentage || 
        Time.now - @previous_time >= 1 ||
        @is_finished
        show
      end
    end

  public
      def file_transfer_mode
      @format_arguments = [:title, :percentage, :bar, :stat_for_file_transfer]  
    end

    def format= (format)
      @format = format
    end

    def format_arguments= (arguments)
      @format_arguments = arguments
    end

    def finish
      @current = @total
      @is_finished = true
      show_progress
    end

    def halt
      @is_finished = true
      show_progress
    end

    def set (count)
      if count < 0 || count > @total
        raise "invalid count: #{count} (total: #{@total})"
      end
      @current = count
      show_progress
      @previous = @current
    end

    def inc (step = 1)
      @current += step
      @current = @total if @current > @total
      show_progress
      @previous = @current
    end

    def inspect
      "(ProgressBar: #{@current}/#{@total})"
    end
  end

  class CommandPattern
    class AbstractCommandError < Exception; end
    class UnknownCommandError < RuntimeError; end
    class CommandAlreadyExists < RuntimeError; end

    class << self
      def add(command)
        command = command.new if command.kind_of?(Class)

        @commands ||= {}
        if @commands.has_key?(command.name)
          raise CommandAlreadyExists
        else
          @commands[command.name] = command
        end

        if command.respond_to?(:altname)
          unless @commands.has_key?(command.altname)
            @commands[command.altname] = command
          end
        end
      end

      def <<(command)
        add(command)
      end

      attr_accessor :default
      def default=(command) #:nodoc:
        if command.kind_of?(CommandPattern)
        @default = command
        elsif command.kind_of?(Class)
          @default = command.new
        elsif @commands.has_key?(command)
          @default = @commands[command]
        else
          raise UnknownCommandError
        end
      end

      def command?(command)
        @commands.has_key?(command)
      end

      def command(command)
        if command?(command)
          @commands[command]
        else
          @default
        end
      end

      def [](cmd)
        self.command(cmd)
      end

      def default_ioe(ioe = {})
        ioe[:input]   ||= $stdin
        ioe[:output]  ||= $stdout
        ioe[:error]   ||= $stderr
        ioe
      end
    end

    def [](args, opts = {}, ioe = {})
      call(args, opts, ioe)
    end

    def name
      raise AbstractCommandError
    end

    def call(args, opts = {}, ioe = {})
      raise AbstractCommandError
    end

    def help
      raise AbstractCommandError
    end
  end

  class CommandHelp < CommandPattern
    def name
      "help"
    end

    def call(args, opts = {}, ioe = {})
      ioe = CommandPattern.default_ioe(ioe)

      help_on = args.shift

      if CommandPattern.command?(help_on)
        ioe[:output] << CommandPattern[help_on].help
      elsif help_on == "commands"
        ioe[:output] << <<-EOH
The commands known to minitar are:

    minitar create          Creates a new tarfile.
    minitar extract         Extracts files from a tarfile.
    minitar list            Lists files in the tarfile.

All commands accept the options --verbose and --progress, which are
mutually exclusive. In "minitar list", --progress means the same as
--verbose.

  --verbose, -V     Performs the requested command verbosely.
  --progress, -P    Shows a progress bar, if appropriate, for the action
                    being performed.

        EOH
      else
        ioe[:output] << "Unknown command: #{help_on}\n" unless help_on.nil? or help_on.empty?
        ioe[:output] << self.help
      end

      0
    end

    def help
      help = <<-EOH
This is a basic help message containing pointers to more information on
how to use this command-line tool. Try:

    minitar help commands       list all 'minitar' commands
    minitar help <COMMAND>      show help on <COMMAND>
                                  (e.g., 'minitar help create')
      EOH
    end
#   minitar add             Adds a file to an existing tarfile.
#   minitar delete          Deletes a file from an existing tarfile.
  end

  class CommandCreate < CommandPattern
    def name
      "create"
    end

    def altname
      "cr"
    end

    def call(args, opts = {}, ioe = {})
      argv    = []

      while (arg = args.shift)
        case arg
        when '--compress', '-z'
          opts[:compress] = true
        else
          argv << arg
        end
      end

      if argv.size < 2
        ioe[:output] << "Not enough arguments.\n\n"
        CommandPattern["help"][["create"]]
        return 255
      end

      output = argv.shift
      if '-' == output
        opts[:name] = "STDOUT"
        output = ioe[:output]
        opts[:output] = ioe[:error]
      else
        opts[:name] = output
        output = File.open(output, "wb")
        opts[:output] = ioe[:output]
      end

      if opts[:name] =~ /\.tar\.gz$|\.tgz$/ or opts[:compress]
        output = Zlib::GzipWriter.new(output)
      end

      files = []
      if argv.include?("--")
          # Read stdin for the list of files.
        files = ""
        files << ioe[:input].read while not ioe[:input].eof?
        files = files.split(/\r\n|\n|\r/)
        args.delete("--")
      end

      files << argv.to_a
      files.flatten!

      if opts[:verbose]
        watcher = lambda do |action, name, stats|
          opts[:output] << "#{name}\n" if action == :dir or action == :file_done
        end
        finisher = lambda { opts[:output] << "\n" }
      elsif opts[:progress]
        progress = ProgressBar.new(opts[:name], 1)
        watcher = lambda do |action, name, stats|
          case action
          when :file_start, :dir
            progress.title = File.basename(name)
            if action == :dir
              progress.total += 1
              progress.inc
            else
              progress.total += stats[:size]
            end
          when :file_progress
            progress.inc(stats[:currinc])
          end
        end
        finisher = lambda do
          progress.title = opts[:name]
          progress.finish
        end
      else
        watcher = nil
        finisher = lambda { }
      end

      Archive::Tar::Minitar.pack(files, output, &watcher)
      finisher.call
      0
    ensure
      output.close if output and not output.closed?
    end

    def help
      help = <<-EOH
    minitar create [OPTIONS] <tarfile|-> <file|directory|-->+

Creates a new tarfile. If the tarfile is named .tar.gz or .tgz, then it
will be compressed automatically. If the tarfile is "-", then it will be
output to standard output (stdout) so that minitar may be piped.

The files or directories that will be packed into the tarfile are
specified after the name of the tarfile itself. Directories will be
processed recursively. If the token "--" is found in the list of files
to be packed, additional filenames will be read from standard input
(stdin). If any file is not found, the packaging will be halted.

create Options:
    --compress, -z  Compresses the tarfile with gzip.

      EOH
    end
  end

  class CommandExtract < CommandPattern
    def name
      "extract"
    end

    def altname
      "ex"
    end

    def call(args, opts = {}, ioe = {})
      argv    = []
      output  = nil
      dest    = "."
      files   = []

      while (arg = args.shift)
        case arg
        when '--uncompress', '-z'
          opts[:uncompress] = true
        when '--pipe'
          opts[:output] = ioe[:error]
          output = ioe[:output]
        when '--output', '-o'
          dest = args.shift
        else
          argv << arg
        end
      end

      if argv.size < 1
        ioe[:output] << "Not enough arguments.\n\n"
        CommandPattern["help"][["extract"]]
        return 255
      end

      input = argv.shift
      if '-' == input
        opts[:name] = "STDIN"
        input = ioe[:input]
      else
        opts[:name] = input
        input = File.open(input, "rb")
      end

      if opts[:name] =~ /\.tar\.gz$|\.tgz$/ or opts[:uncompress]
        input = Zlib::GzipReader.new(input)
      end

      files << argv.to_a
      files.flatten!

      if opts[:verbose]
        watcher = lambda do |action, name, stats|
          opts[:output] << "#{name}\n" if action == :dir or action == :file_done
        end
        finisher = lambda { opts[:output] << "\n" }
      elsif opts[:progress]
        progress = ProgressBar.new(opts[:name], 1)
        watcher = lambda do |action, name, stats|
          case action
          when :file_start, :dir
            progress.title = File.basename(name)
            if action == :dir
              progress.total += 1
              progress.inc
            else
              progress.total += stats[:entry].size
            end
          when :file_progress
            progress.inc(stats[:currinc])
          end
        end
        finisher = lambda do
          progress.title = opts[:name]
          progress.finish
        end
      else
        watcher = nil
        finisher = lambda { }
      end

      if output.nil?
        Archive::Tar::Minitar.unpack(input, dest, files, &watcher)
        finisher.call
      else
        Archive::Tar::Minitar::Input.open(input) do |inp|
          inp.each do |entry|
            stats = {
              :mode     => entry.mode,
              :mtime    => entry.mtime,
              :size     => entry.size,
              :gid      => entry.gid,
              :uid      => entry.uid,
              :current  => 0,
              :currinc  => 0,
              :entry    => entry
            }

            if files.empty? or files.include?(entry.full_name)
              if entry.directory?
                puts "Directory: #{entry.full_name}"
                watcher[:dir, dest, stats] unless watcher.nil?
              else
                puts "File: #{entry.full_name}"
                watcher[:file_start, destfile, stats] unless watcher.nil?
                loop do
                  data = entry.read(4096)
                  break unless data
                  stats[:currinc] = output.write(data)
                  stats[:current] += stats[:currinc]

                  watcher[:file_progress, name, stats] unless watcher.nil?
                end
                watcher[:file_done, name, stats] unless watcher.nil?
              end
            end
          end
        end
      end

      0
    end

    def help
      help = <<-EOH
    minitar extract [OPTIONS] <tarfile|-> [<file>+]

Extracts files from an existing tarfile. If the tarfile is named .tar.gz
or .tgz, then it will be uncompressed automatically. If the tarfile is
"-", then it will be read from standard input (stdin) so that minitar
may be piped.

The files or directories that will be extracted from the tarfile are
specified after the name of the tarfile itself. Directories will be
processed recursively. Files must be specified in full. A file
"foo/bar/baz.txt" cannot simply be specified by specifying "baz.txt".
Any file not found will simply be skipped and an error will be reported.

extract Options:
    --uncompress, -z  Uncompresses the tarfile with gzip.
    --pipe            Emits the extracted files to STDOUT for piping.
    --output, -o      Extracts the files to the specified directory.

      EOH
    end
  end

  class CommandList < CommandPattern
    def name
      "list"
    end

    def altname
      "ls"
    end

    def modestr(mode)
      s = "---"
      s[0] = ?r if (mode & 4) == 4
      s[1] = ?w if (mode & 2) == 2
      s[2] = ?x if (mode & 1) == 1
      s
    end

    def call(args, opts = {}, ioe = {})
      argv    = []
      output  = nil
      dest    = "."
      files   = []
      opts[:field] = "name"

      while (arg = args.shift)
        case arg
        when '--sort', '-S'
          opts[:sort]   = true
          opts[:field]  = args.shift
        when '--reverse', '-R'
          opts[:reverse] = true
          opts[:sort]    = true
        when '--uncompress', '-z'
          opts[:uncompress] = true
        when '-l'
          opts[:verbose] = true
        else
          argv << arg
        end
      end

      if argv.size < 1
        ioe[:output] << "Not enough arguments.\n\n"
        CommandPattern["help"][["list"]]
        return 255
      end

      input = argv.shift
      if '-' == input
        opts[:name] = "STDIN"
        input = ioe[:input]
      else
        opts[:name] = input
        input = File.open(input, "rb")
      end

      if opts[:name] =~ /\.tar\.gz$|\.tgz$/ or opts[:uncompress]
        input = Zlib::GzipReader.new(input)
      end

      files << argv.to_a
      files.flatten!

      if opts[:verbose] or opts[:progress]
        format  = "%10s %4d %8s %8s %8d %12s %s"
        datefmt = "%b %d  %Y"
        timefmt = "%b %d %H:%M"
        fields  = %w(permissions inodes user group size date fullname)
      else
        format  = "%s"
        fields  = %w(fullname)
      end

      opts[:field] = opts[:field].intern
      opts[:field] = :full_name if opts[:field] == :name

      output = []

      Archive::Tar::Minitar::Input.open(input) do |inp|
        today = Time.now
        oneyear = Time.mktime(today.year - 1, today.month, today.day)
        inp.each do |entry|
          value = format % fields.map do |ff|
            case ff
            when "permissions"
              s = entry.directory? ? "d" : "-"
              s << modestr(entry.mode / 0100)
              s << modestr(entry.mode / 0010)
              s << modestr(entry.mode)
            when "inodes"
              entry.size / 512
            when "user"
              entry.uname || entry.uid || 0
            when "group"
              entry.gname || entry.gid || 0
            when "size"
              entry.size
            when "date"
              if Time.at(entry.mtime) > (oneyear)
                Time.at(entry.mtime).strftime(timefmt)
              else
                Time.at(entry.mtime).strftime(datefmt)
              end
            when "fullname"
              entry.full_name
            end
          end

          if opts[:sort]
            output << [entry.send(opts[:field]), value]
          else
            ioe[:output] << value << "\n"
          end

        end
      end

      if opts[:sort]
        output = output.sort { |a, b| a[0] <=> b[0] }
        if opts[:reverse]
          output.reverse_each { |oo| ioe[:output] << oo[1] << "\n" }
        else
          output.each { |oo| ioe[:output] << oo[1] << "\n" }
        end
      end

      0
    end

    def help
      help = <<-EOH
    minitar list [OPTIONS] <tarfile|-> [<file>+]

Lists files in an existing tarfile. If the tarfile is named .tar.gz or
.tgz, then it will be uncompressed automatically. If the tarfile is "-",
then it will be read from standard input (stdin) so that minitar may be
piped.

If --verbose or --progress is specified, then the file list will be
similar to that produced by the Unix command "ls -l".

list Options:
    --uncompress, -z      Uncompresses the tarfile with gzip.
    --sort [<FIELD>], -S  Sorts the list of files by the specified
                          field. The sort defaults to the filename.
    --reverse, -R         Reverses the sort.
    -l                    Lists the files in detail.

Sort Fields:
  name, mtime, size

      EOH
    end
  end

  CommandPattern << CommandHelp
  CommandPattern << CommandCreate
  CommandPattern << CommandExtract
  CommandPattern << CommandList
# CommandPattern << CommandAdd
# CommandPattern << CommandDelete

  def self.run(argv, input = $stdin, output = $stdout, error = $stderr)
    ioe = {
      :input  => input,
      :output => output,
      :error  => error,
    }
    opts = { }

    if argv.include?("--version")
      output << <<-EOB
minitar #{Archive::Tar::Minitar::VERSION}
  Copyright 2004 Mauricio Julio Ferna'ndez Pradier and Austin Ziegler
  This is free software with ABSOLUTELY NO WARRANTY.

  see http://rubyforge.org/projects/ruwiki for more information
      EOB
    end

    if argv.include?("--verbose") or argv.include?("-V")
      opts[:verbose]  = true
      argv.delete("--verbose")
      argv.delete("-V")
    end

    if argv.include?("--progress") or argv.include?("-P")
      opts[:progress] = true
      opts[:verbose]  = false
      argv.delete("--progress")
      argv.delete("-P")
    end

    command = CommandPattern[(argv.shift or "").downcase]
    command ||= CommandPattern["help"]
    return command[argv, opts, ioe]
  end
end

# end of embeding under the Puppet::Util namesapce
end
end
