#!/usr/bin/env ruby

require 'optparse'
require 'sys/proctable'
include Sys

class CheckPuppet

  VERSION = '0.1'
  script_name = File.basename($0)

  # default options
  OPTIONS = {
    :statefile => "/var/lib/puppet/state/state.yaml",
    :process   => "puppetd",
    :interval  => 30,
  }

  o = OptionParser.new do |o|
    o.set_summary_indent('  ')
    o.banner =    "Usage: #{script_name} [OPTIONS]"
    o.define_head "The check_puppet Nagios plug-in checks that specified Puppet process is running and the state file is no older than specified interval."
      o.separator   ""
      o.separator   "Mandatory arguments to long options are mandatory for short options too."


        o.on(
          "-s", "--statefile=statefile", String, "The state file",

    "Default: #{OPTIONS[:statefile]}") { |OPTIONS[:statefile]| }

      o.on(
        "-p", "--process=processname", String, "The process to check",

    "Default: #{OPTIONS[:process]}")   { |OPTIONS[:process]| }

      o.on(
        "-i", "--interval=value", Integer,

    "Default: #{OPTIONS[:interval]} minutes")  { |OPTIONS[:interval]| }

    o.separator ""
    o.on_tail("-h", "--help", "Show this help message.") do
      puts o
      exit
    end

    o.parse!(ARGV)
  end

  def check_proc

    unless ProcTable.ps.find { |p| p.name == OPTIONS[:process]}
      @proc = 2
    else
      @proc = 0
    end

  end

  def check_state

    # Set variables
    curt = Time.now
    intv = OPTIONS[:interval] * 60

    # Check file time
    begin
      @modt = File.mtime("#{OPTIONS[:statefile]}")
    rescue
      @file = 3
    end

    diff = (curt - @modt).to_i

    if diff > intv
      @file = 2
    else
      @file = 0
    end

  end

  def output_status

    case @file
    when 0
      state = "state file status okay updated on " + @modt.strftime("%m/%d/%Y at %H:%M:%S")
    when 2
      state = "state fille is not up to date and is older than #{OPTIONS[:interval]} minutes"
    when 3
      state = "state file status unknown"
    end

    case @proc
    when 0
      process = "process #{OPTIONS[:process]} is running"
    when 2
      process = "process #{OPTIONS[:process]} is not running"
    end

    case @proc or @file
    when 0
      status = "OK"
      exitcode = 0
    when 2
      status = "CRITICAL"
      exitcode = 2
    when 3
      status = "UNKNOWN"
      exitcide = 3
    end

    puts "PUPPET #{status}: #{process}, #{state}"
    exit(exitcode)
  end
end

cp = CheckPuppet.new
cp.check_proc
cp.check_state
cp.output_status

