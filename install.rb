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
#++

require 'rbconfig'
require 'find'
require 'fileutils'
begin
  require 'ftools' # apparently on some system ftools doesn't get loaded
  $haveftools = true
rescue LoadError
  puts "ftools not found.  Using FileUtils instead.."
  $haveftools = false
end
require 'optparse'
require 'ostruct'

begin
    require 'rdoc/rdoc'
    $haverdoc = true
rescue LoadError
    puts "Missing rdoc; skipping documentation"
    $haverdoc = false
end

begin
    if $haverdoc
       rst2man = %x{which rst2man.py}
       $haveman = true
    else
       $haveman = false
    end
rescue
    puts "Missing rst2man; skipping man page creation"
    $haveman = false
end

PREREQS = %w{openssl facter xmlrpc/client xmlrpc/server cgi}
MIN_FACTER_VERSION = 1.5

InstallOptions = OpenStruct.new

def glob(list)
    g = list.map { |i| Dir.glob(i) }
    g.flatten!
    g.compact!
    g.reject! { |e| e =~ /\.svn/ }
    g
end

# Set these values to what you want installed.
sbins = glob(%w{sbin/*})
bins  = glob(%w{bin/*})
rdoc  = glob(%w{bin/* sbin/* lib/**/*.rb README README-library CHANGELOG TODO Install}).reject { |e| e=~ /\.(bat|cmd)$/ }
ri    = glob(%w(bin/*.rb sbin/* lib/**/*.rb)).reject { |e| e=~ /\.(bat|cmd)$/ }
man   = glob(%w{man/man[0-9]/*})
libs  = glob(%w{lib/**/*.rb lib/**/*.py})
tests = glob(%w{test/**/*.rb})

def do_bins(bins, target, strip = 's?bin/')
  bins.each do |bf|
    obf = bf.gsub(/#{strip}/, '')
    install_binfile(bf, obf, target)
  end
end

def do_libs(libs, strip = 'lib/')
  libs.each do |lf|
    olf = File.join(InstallOptions.site_dir, lf.gsub(/#{strip}/, ''))
    op = File.dirname(olf)
    if $haveftools
      File.makedirs(op, true)
      File.chmod(0755, op)
      File.install(lf, olf, 0644, true)
    else
      FileUtils.makedirs(op, {:mode => 0755, :verbose => true})
      FileUtils.chmod(0755, op)
      FileUtils.install(lf, olf, {:mode => 0644, :verbose => true})
    end
  end
end

def do_man(man, strip = 'man/')
  man.each do |mf|
    omf = File.join(InstallOptions.man_dir, mf.gsub(/#{strip}/, ''))
    om = File.dirname(omf)
    if $haveftools
      File.makedirs(om, true)
      File.chmod(0755, om)
      File.install(mf, omf, 0644, true)
    else
      FileUtils.makedirs(om, {:mode => 0755, :verbose => true})
      FileUtils.chmod(0755, om)
      FileUtils.install(mf, omf, {:mode => 0644, :verbose => true})
    end
    gzip = %x{which gzip}
    gzip.chomp!
    %x{#{gzip} -f #{omf}}
  end
end

# Verify that all of the prereqs are installed
def check_prereqs
    PREREQS.each { |pre|
        begin
            require pre
            if pre == "facter"
              # to_f isn't quite exact for strings like "1.5.1" but is good
              # enough for this purpose.
              facter_version = Facter.version.to_f
              if facter_version < MIN_FACTER_VERSION
                puts "Facter version: %s; minimum required: %s; cannot install" % [facter_version, MIN_FACTER_VERSION]
                exit -1
              end
            end
        rescue LoadError
            puts "Could not load %s; cannot install" % pre
            exit -1
        end
    }
end

##
# Prepare the file installation.
#
def prepare_installation
  # Only try to do docs if we're sure they have rdoc
  if $haverdoc
      InstallOptions.rdoc  = true
      if RUBY_PLATFORM == "i386-mswin32"
        InstallOptions.ri  = false
      else
        InstallOptions.ri  = true
      end
  else
      InstallOptions.rdoc  = false
      InstallOptions.ri  = false
  end


  if $haveman
      InstallOptions.man = true
      if RUBY_PLATFORM == "i386-mswin32"
        InstallOptions.man  = false
      end
  else
      InstallOptions.man = false
  end

  InstallOptions.tests = true

  if $haveman
      InstallOptions.man = true
      if RUBY_PLATFORM == "i386-mswin32"
        InstallOptions.man  = false
      end
  else
      InstallOptions.man = false
  end

  ARGV.options do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options]"
    opts.separator ""
    opts.on('--[no-]rdoc', 'Prevents the creation of RDoc output.', 'Default on.') do |onrdoc|
      InstallOptions.rdoc = onrdoc
    end
    opts.on('--[no-]ri', 'Prevents the creation of RI output.', 'Default off on mswin32.') do |onri|
      InstallOptions.ri = onri
    end
    opts.on('--[no-]man', 'Prevents the creation of man pages.', 'Default on.') do |onman|
    InstallOptions.man = onman
    end
    opts.on('--[no-]tests', 'Prevents the execution of unit tests.', 'Default on.') do |ontest|
      InstallOptions.tests = ontest
    end
    opts.on('--destdir[=OPTIONAL]', 'Installation prefix for all targets', 'Default essentially /') do |destdir|
      InstallOptions.destdir = destdir
    end
    opts.on('--bindir[=OPTIONAL]', 'Installation directory for binaries', 'overrides Config::CONFIG["bindir"]') do |bindir|
      InstallOptions.bindir = bindir
    end
    opts.on('--sbindir[=OPTIONAL]', 'Installation directory for system binaries', 'overrides Config::CONFIG["sbindir"]') do |sbindir|
      InstallOptions.sbindir = sbindir
    end
    opts.on('--sitelibdir[=OPTIONAL]', 'Installation directory for libraries', 'overrides Config::CONFIG["sitelibdir"]') do |sitelibdir|
      InstallOptions.sitelibdir = sitelibdir
    end
    opts.on('--mandir[=OPTIONAL]', 'Installation directory for man pages', 'overrides Config::CONFIG["mandir"]') do |mandir|
      InstallOptions.mandir = mandir
    end
    opts.on('--quick', 'Performs a quick installation. Only the', 'installation is done.') do |quick|
      InstallOptions.rdoc   = false
      InstallOptions.ri     = false
      InstallOptions.tests  = false
    end
    opts.on('--full', 'Performs a full installation. All', 'optional installation steps are run.') do |full|
      InstallOptions.rdoc   = true
      InstallOptions.man    = true
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

  tmpdirs = [".", ENV['TMP'], ENV['TEMP'], "/tmp", "/var/tmp"]

  version = [Config::CONFIG["MAJOR"], Config::CONFIG["MINOR"]].join(".")
  libdir = File.join(Config::CONFIG["libdir"], "ruby", version)

  # Mac OS X 10.5 and higher declare bindir and sbindir as
  # /System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin
  # /System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/sbin
  # which is not generally where people expect executables to be installed
  # These settings are appropriate defaults for all OS X versions.
  if RUBY_PLATFORM =~ /^universal-darwin[\d\.]+$/
    Config::CONFIG['bindir'] = "/usr/bin"
    Config::CONFIG['sbindir'] = "/usr/sbin"
  end

  if not InstallOptions.bindir.nil?
    bindir = InstallOptions.bindir
  else
    bindir = Config::CONFIG['bindir']
  end

  if not InstallOptions.sbindir.nil?
    sbindir = InstallOptions.sbindir
  else
    sbindir = Config::CONFIG['sbindir']
  end

  if not InstallOptions.sitelibdir.nil?
    sitelibdir = InstallOptions.sitelibdir
  else
    sitelibdir = Config::CONFIG["sitelibdir"]
    if sitelibdir.nil?
      sitelibdir = $:.find { |x| x =~ /site_ruby/ }
      if sitelibdir.nil?
        sitelibdir = File.join(libdir, "site_ruby")
      elsif sitelibdir !~ Regexp.quote(version)
        sitelibdir = File.join(sitelibdir, version)
      end
    end
  end

  if not InstallOptions.mandir.nil?
    mandir = InstallOptions.mandir
  else
    mandir = Config::CONFIG['mandir']
  end

  # To be deprecated once people move over to using --destdir option
  if (destdir = ENV['DESTDIR'])
    bindir = "#{destdir}#{bindir}"
    sbindir = "#{destdir}#{sbindir}"
    mandir = "#{destdir}#{mandir}"
    sitelibdir = "#{destdir}#{sitelibdir}"

    FileUtils.makedirs(bindir)
    FileUtils.makedirs(sbindir)
    FileUtils.makedirs(mandir)
    FileUtils.makedirs(sitelibdir)
  # This is the new way forward
  elsif (destdir = InstallOptions.destdir)
    bindir = "#{destdir}#{bindir}"
    sbindir = "#{destdir}#{sbindir}"
    mandir = "#{destdir}#{mandir}"
    sitelibdir = "#{destdir}#{sitelibdir}"

    FileUtils.makedirs(bindir)
    FileUtils.makedirs(sbindir)
    FileUtils.makedirs(mandir)
    FileUtils.makedirs(sitelibdir)
  end

  tmpdirs << bindir

  InstallOptions.tmp_dirs = tmpdirs.compact
  InstallOptions.site_dir = sitelibdir
  InstallOptions.bin_dir  = bindir
  InstallOptions.sbin_dir = sbindir
  InstallOptions.lib_dir  = libdir
  InstallOptions.man_dir  = mandir
end

##
# Build the rdoc documentation. Also, try to build the RI documentation.
#
def build_rdoc(files)
    return unless $haverdoc
    begin
        r = RDoc::RDoc.new
        r.document(["--main", "README", "--title",
            "Puppet -- Site Configuration Management", "--line-numbers"] + files)
    rescue RDoc::RDocError => e
        $stderr.puts e.message
    rescue Exception => e
        $stderr.puts "Couldn't build RDoc documentation\n#{e.message}"
    end
end

def build_ri(files)
    return unless $haverdoc
    begin
        ri = RDoc::RDoc.new
        #ri.document(["--ri-site", "--merge"] + files)
        ri.document(["--ri-site"] + files)
    rescue RDoc::RDocError => e
        $stderr.puts e.message
    rescue Exception => e
        $stderr.puts "Couldn't build Ri documentation\n#{e.message}"
        $stderr.puts "Continuing with install..."
    end
end

def build_man(bins)
    return unless $haveman
    begin
        # Locate rst2man
        rst2man = %x{which rst2man.py}
        rst2man.chomp!
        # Create puppet.conf.5 man page
        %x{bin/puppetdoc --reference configuration > ./puppet.conf.rst}
        %x{#{rst2man} ./puppet.conf.rst ./man/man5/puppet.conf.5}
        File.unlink("./puppet.conf.rst")

        # Create binary man pages
        bins.each do |bin|
          b = bin.gsub( "bin/", "")
          %x{#{bin} --help > ./#{b}.rst}
          %x{#{rst2man} ./#{b}.rst ./man/man8/#{b}.8}
          File.unlink("./#{b}.rst")
        end
    rescue SystemCallError
        $stderr.puts "Couldn't build man pages: " + $!
        $stderr.puts "Continuing with install..."
    end
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
  InstallOptions.tmp_dirs.each do |t|
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
      contents = ip.readlines
      if contents[0] =~ /^#!/
          contents.shift
      end
      op.write contents.join()
    end
  end

  if Config::CONFIG["target_os"] =~ /win/io and Config::CONFIG["target_os"] !~ /darwin/io
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

check_prereqs
prepare_installation

#run_tests(tests) if InstallOptions.tests
#build_rdoc(rdoc) if InstallOptions.rdoc
#build_ri(ri) if InstallOptions.ri
#build_man(bins) if InstallOptions.man
do_bins(sbins, InstallOptions.sbin_dir)
do_bins(bins, InstallOptions.bin_dir)
do_libs(libs)
do_man(man)
