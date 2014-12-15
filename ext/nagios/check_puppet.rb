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

  OptionParser.new do |o|
    o.set_summary_indent('  ')
    o.banner =    "Usage: #{script_name} [OPTIONS]"
    o.define_head "The check_puppet Nagios plug-in checks that specified Puppet process is running and the state file is no older than specified interval."
      o.separator   ""
      o.separator   "Mandatory arguments to long options are mandatory for short options too."


        o.on(
          "-s", "--statefile=statefile", String, "The state file",

    "Default: #{OPTIONS[:statefile]}") { |op| OPTIONS[:statefile] = op }

      o.on(
        "-p", "--process=processname", String, "The process to check",

    "Default: #{OPTIONS[:process]}")   { |op| OPTIONS[:process] = op }

      o.on(
        "-i", "--interval=value", Integer,

    "Default: #{OPTIONS[:interval]} minutes")  { |op| OPTIONS[:interval] = op }

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

    case
    when (@proc == 2 or @file == 2)
      status = "CRITICAL"
      exitcode = 2
    when (@proc == 0 and @file == 0)
      status = "OK"
      exitcode = 0
    else
      status = "UNKNOWN"
      exitcode = 3
    end

    puts "PUPPET #{status}: #{process}, #{state}"
    exit(exitcode)
  end
end

cp = CheckPuppet.new
cp.check_proc
cp.check_state
cp.output_status

