#! /usr/bin/env ruby
#--
# Copyright 2004 Austin Ziegler <ruby-install@halostatue.ca>
#   Install utility. Based on the original installation script for rdoc by the
#   Pragmatic Programmers.
#
# This program is free software. It may be redistributed and/or modified under
# the terms of the GPL version 2 (or later) or the Ruby licence.
#
# Usage
# -----
# In most cases, if you have a typical project layout, you will need to do
# absolutely nothing to make this work for you. This layout is:
#
#   bin/    # executable files -- "commands"
#   lib/    # the source of the library
#   tests/  # unit tests
#
# The default behaviour:
# 1) Run all unit test files (ending in .rb) found in all directories under
#    tests/.
# 2) Build Rdoc documentation from all files in bin/ (excluding .bat and .cmd),
#    all .rb files in lib/, ./README, ./ChangeLog, and ./Install.
# 3) Build ri documentation from all files in bin/ (excluding .bat and .cmd),
#    and all .rb files in lib/. This is disabled by default on Win32.
# 4) Install commands from bin/ into the Ruby bin directory. On Windows, if a
#    if a corresponding batch file (.bat or .cmd) exists in the bin directory,
#    it will be copied over as well. Otherwise, a batch file (always .bat) will
#    be created to run the specified command.
# 5) Install all library files ending in .rb from lib/ into Ruby's
#    site_lib/version directory.
#
# $Id$
#++

require 'rbconfig'
require 'find'
require 'fileutils'
require 'rdoc/rdoc'
require 'optparse'
require 'ostruct'

InstallOptions = OpenStruct.new

def glob(list)
  g = list.map { |i| Dir.glob(i) }
  g.flatten!
  g.compact!
  g.reject! { |e| e =~ /\.svn/ }
  g
end

  # Set these values to what you want installed.
bins  = %w{bin/puppeter}
rdoc  = glob(%w{bin/puppeter lib/**/*.rb README ChangeLog Install}).reject { |e| e=~ /\.(bat|cmd)$/ }
ri    = glob(%w(bin/**/*.rb lib/**/*.rb)).reject { |e| e=~ /\.(bat|cmd)$/ }
libs  = glob(%w{lib/**/*.rb})
tests = glob(%w{tests/**/*.rb})

def do_bins(bins, target, strip = 'bin/')
  bins.each do |bf|
    obf = bf.gsub(/#{strip}/, '')
    install_binfile(bf, obf, target)
  end
end

def do_libs(libs, strip = 'lib/')
  libs.each do |lf|
    olf = File.join(InstallOptions.site_dir, lf.gsub(/#{strip}/, ''))
    op = File.dirname(olf)
    File.makedirs(op, true)
    File.chmod(0755, op)
    File.install(lf, olf, 0755, true)
  end
end

##
# Prepare the file installation.
#
def prepare_installation
  InstallOptions.rdoc  = true
  if RUBY_PLATFORM == "i386-mswin32"
    InstallOptions.ri  = false
  else
    InstallOptions.ri  = true
  end
  InstallOptions.tests = true

  ARGV.options do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options]"
    opts.separator ""
    opts.on('--[no-]rdoc', 'Prevents the creation of RDoc output.', 'Default on.') do |onrdoc|
      InstallOptions.rdoc = onrdoc
    end
    opts.on('--[no-]ri', 'Prevents the creation of RI output.', 'Default off on mswin32.') do |onri|
      InstallOptions.ri = onri
    end
    opts.on('--[no-]tests', 'Prevents the execution of unit tests.', 'Default on.') do |ontest|
      InstallOptions.tests = ontest
    end
    opts.on('--quick', 'Performs a quick installation. Only the', 'installation is done.') do |quick|
      InstallOptions.rdoc   = false
      InstallOptions.ri     = false
      InstallOptions.tests  = false
    end
    opts.on('--full', 'Performs a full installation. All', 'optional installation steps are run.') do |full|
      InstallOptions.rdoc   = true
      InstallOptions.ri     = true
      InstallOptions.tests  = true
    end
    opts.separator("")
    opts.on_tail('--help', "Shows this help text.") do
      $stderr.puts opts
      exit
    end

    opts.parse!
  end

  bds = [".", ENV['TMP'], ENV['TEMP']]

  version = [Config::CONFIG["MAJOR"], Config::CONFIG["MINOR"]].join(".")
  ld = File.join(Config::CONFIG["libdir"], "ruby", version)

  sd = Config::CONFIG["sitelibdir"]
  if sd.nil?
    sd = $:.find { |x| x =~ /site_ruby/ }
    if sd.nil?
      sd = File.join(ld, "site_ruby")
    elsif sd !~ Regexp.quote(version)
      sd = File.join(sd, version)
    end
  end

  if (destdir = ENV['DESTDIR'])
    bd = "#{destdir}#{Config::CONFIG['bindir']}"
    sd = "#{destdir}#{sd}"
    bds << bd

    FileUtils.makedirs(bd)
    FileUtils.makedirs(sd)
  else
    bds << Config::CONFIG['bindir']
  end

  InstallOptions.bin_dirs = bds.compact
  InstallOptions.site_dir = sd
  InstallOptions.bin_dir  = bd
  InstallOptions.lib_dir  = ld
end

##
# Build the rdoc documentation. Also, try to build the RI documentation.
#
def build_rdoc(files)
  r = RDoc::RDoc.new
  r.document(["--main", "README", "--title", "Diff::LCS -- A Diff Algorithm",
              "--line-numbers"] + files)

rescue RDoc::RDocError => e
  $stderr.puts e.message
rescue Exception => e
  $stderr.puts "Couldn't build RDoc documentation\n#{e.message}"
end

def build_ri(files)
  ri = RDoc::RDoc.new
  ri.document(["--ri-site", "--merge"] + files)
rescue RDoc::RDocError => e
  $stderr.puts e.message
rescue Exception => e
  $stderr.puts "Couldn't build Ri documentation\n#{e.message}"
end

def run_tests(test_list)
	begin
		require 'test/unit/ui/console/testrunner'
		$:.unshift "lib"
		test_list.each do |test|
		next if File.directory?(test)
		require test
		end

		tests = []
		ObjectSpace.each_object { |o| tests << o if o.kind_of?(Class) } 
		tests.delete_if { |o| !o.ancestors.include?(Test::Unit::TestCase) }
		tests.delete_if { |o| o == Test::Unit::TestCase }

		tests.each { |test| Test::Unit::UI::Console::TestRunner.run(test) }
		$:.shift
	rescue LoadError
		puts "Missing testrunner library; skipping tests"
	end
end

##
# Install file(s) from ./bin to Config::CONFIG['bindir']. Patch it on the way
# to insert a #! line; on a Unix install, the command is named as expected
# (e.g., bin/rdoc becomes rdoc); the shebang line handles running it. Under
# windows, we add an '.rb' extension and let file associations do their stuff.
def install_binfile(from, op_file, target)
  tmp_dir = nil
  InstallOptions.bin_dirs.each do |t|
    if File.directory?(t) and File.writable?(t)
      tmp_dir = t
      break
    end
  end
  
  fail "Cannot find a temporary directory" unless tmp_dir
  tmp_file = File.join(tmp_dir, '_tmp')
  ruby = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])

  File.open(from) do |ip|
    File.open(tmp_file, "w") do |op|
      ruby = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
      op.puts "#!#{ruby}"
      op.write ip.read
    end
  end

  if Config::CONFIG["target_os"] =~ /win/io
    installed_wrapper = false

    if File.exists?("#{from}.bat")
      FileUtils.install("#{from}.bat", File.join(target, "#{op_file}.bat"), :mode => 0755, :verbose => true)
      installed_wrapper = true
    end

    if File.exists?("#{from}.cmd")
      FileUtils.install("#{from}.cmd", File.join(target, "#{op_file}.cmd"), :mode => 0755, :verbose => true)
      installed_wrapper = true
    end

    if not installed_wrapper
      tmp_file2 = File.join(tmp_dir, '_tmp_wrapper')
      cwn = File.join(Config::CONFIG['bindir'], op_file)
      cwv = CMD_WRAPPER.gsub('<ruby>', ruby.gsub(%r{/}) { "\\" }).gsub!('<command>', cwn.gsub(%r{/}) { "\\" } )

      File.open(tmp_file2, "wb") { |cw| cw.puts cwv }
      FileUtils.install(tmp_file2, File.join(target, "#{op_file}.bat"), :mode => 0755, :verbose => true)

      File.unlink(tmp_file2)
      installed_wrapper = true
    end
  end
  FileUtils.install(tmp_file, File.join(target, op_file), :mode => 0755, :verbose => true)
  File.unlink(tmp_file)
end

CMD_WRAPPER = <<-EOS
@echo off
if "%OS%"=="Windows_NT" goto WinNT
<ruby> -x "<command>" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto done
:WinNT
<ruby> -x "<command>" %*
goto done
:done
EOS

prepare_installation

run_tests(tests) if InstallOptions.tests
build_rdoc(rdoc) if InstallOptions.rdoc
build_ri(ri) if InstallOptions.ri
do_bins(bins, Config::CONFIG['bindir'])
do_libs(libs)
