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
#
# The default behaviour:
# 1) Build Rdoc documentation from all files in bin/ (excluding .bat and .cmd),
#    all .rb files in lib/, ./README, ./ChangeLog, and ./Install.
# 2) Build ri documentation from all files in bin/ (excluding .bat and .cmd),
#    and all .rb files in lib/. This is disabled by default on Microsoft Windows.
# 3) Install commands from bin/ into the Ruby bin directory. On Windows, if a
#    if a corresponding batch file (.bat or .cmd) exists in the bin directory,
#    it will be copied over as well. Otherwise, a batch file (always .bat) will
#    be created to run the specified command.
# 4) Install all library files ending in .rb from lib/ into Ruby's
#    site_lib/version directory.
#
#++

require 'rbconfig'
require 'find'
require 'fileutils'
require 'tempfile'
require 'optparse'
require 'ostruct'

PREREQS = %w{openssl facter cgi}
MIN_FACTER_VERSION = 1.5

InstallOptions = OpenStruct.new

def glob(list)
  g = list.map { |i| Dir.glob(i) }
  g.flatten!
  g.compact!
  g
end

def do_configs(configs, target, strip = 'conf/')
  Dir.mkdir(target) unless File.directory? target
  configs.each do |cf|
    ocf = File.join(InstallOptions.config_dir, cf.gsub(/#{strip}/, ''))
    FileUtils.install(cf, ocf, mode: 0644, preserve: true, verbose: true)
  end
end

def do_bins(bins, target, strip = 's?bin/')
  Dir.mkdir(target) unless File.directory? target
  bins.each do |bf|
    obf = bf.gsub(/#{strip}/, '')
    install_binfile(bf, obf, target)
  end
end

def do_libs(libs, strip = 'lib/')
  libs.each do |lf|
    next if File.directory? lf
    olf = File.join(InstallOptions.site_dir, lf.sub(/^#{strip}/, ''))
    op = File.dirname(olf)
    FileUtils.makedirs(op, mode: 0755, verbose: true)
    FileUtils.chmod(0755, op)
    FileUtils.install(lf, olf, mode: 0644, preserve: true, verbose: true)
  end
end

def do_man(man, strip = 'man/')
  man.each do |mf|
    omf = File.join(InstallOptions.man_dir, mf.gsub(/#{strip}/, ''))
    om = File.dirname(omf)
    FileUtils.makedirs(om, mode: 0755, verbose: true)
    FileUtils.chmod(0755, om)
    FileUtils.install(mf, omf, mode: 0644, preserve: true, verbose: true)
    # Solaris does not support gzipped man pages. When called with
    # --no-check-prereqs/without facter the default gzip behavior still applies
    unless $osname == "Solaris"
      gzip = %x{which gzip}
      gzip.chomp!
      %x{#{gzip} -f #{omf}}
    end
  end
end

def do_locales(locale, strip = 'locales/')
  locale.each do |lf|
    next if File.directory? lf
    olf = File.join(InstallOptions.locale_dir, lf.sub(/^#{strip}/, ''))
    op = File.dirname(olf)
    FileUtils.makedirs(op, mode: 0755, verbose: true)
    FileUtils.chmod(0755, op)
    FileUtils.install(lf, olf, mode: 0644, preserve: true, verbose: true)
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
          puts "Facter version: #{facter_version}; minimum required: #{MIN_FACTER_VERSION}; cannot install"
          exit(-1)
        end
      end
    rescue LoadError
      puts "Could not load #{pre}; cannot install"
      exit(-1)
    end
  }
end

##
# Prepare the file installation.
#
def prepare_installation
  InstallOptions.configs = true
  InstallOptions.check_prereqs = true
  InstallOptions.batch_files = true

  ARGV.options do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options]"
    opts.separator ""
    opts.on('--[no-]configs', 'Prevents the installation of config files', 'Default off.') do |ontest|
      InstallOptions.configs = ontest
    end
    opts.on('--destdir[=OPTIONAL]', 'Installation prefix for all targets', 'Default essentially /') do |destdir|
      InstallOptions.destdir = destdir
    end
    opts.on('--configdir[=OPTIONAL]', 'Installation directory for config files', 'Default /etc/puppetlabs/puppet') do |configdir|
      InstallOptions.configdir = configdir
    end
    opts.on('--codedir[=OPTIONAL]', 'Installation directory for code files', 'Default /etc/puppetlabs/code') do |codedir|
      InstallOptions.codedir = codedir
    end
    opts.on('--vardir[=OPTIONAL]', 'Installation directory for var files', 'Default /opt/puppetlabs/puppet/cache') do |vardir|
      InstallOptions.vardir = vardir
    end
    opts.on('--publicdir[=OPTIONAL]', 'Installation directory for public files such as the `last_run_summary.yaml` report', 'Default /opt/puppetlabs/puppet/public') do |publicdir|
      InstallOptions.publicdir = publicdir
    end
    opts.on('--rundir[=OPTIONAL]', 'Installation directory for state files', 'Default /var/run/puppetlabs') do |rundir|
      InstallOptions.rundir = rundir
    end
    opts.on('--logdir[=OPTIONAL]', 'Installation directory for log files', 'Default /var/log/puppetlabs/puppet') do |logdir|
      InstallOptions.logdir = logdir
    end
    opts.on('--bindir[=OPTIONAL]', 'Installation directory for binaries', 'overrides RbConfig::CONFIG["bindir"]') do |bindir|
      InstallOptions.bindir = bindir
    end
    opts.on('--localedir[=OPTIONAL]', 'Installation directory for locale information', 'Default /opt/puppetlabs/puppet/share/locale') do |localedir|
      InstallOptions.localedir = localedir
    end
    opts.on('--ruby[=OPTIONAL]', 'Ruby interpreter to use with installation', 'overrides ruby used to call install.rb') do |ruby|
      InstallOptions.ruby = ruby
    end
    opts.on('--sitelibdir[=OPTIONAL]', 'Installation directory for libraries', 'overrides RbConfig::CONFIG["sitelibdir"]') do |sitelibdir|
      InstallOptions.sitelibdir = sitelibdir
    end
    opts.on('--mandir[=OPTIONAL]', 'Installation directory for man pages', 'overrides RbConfig::CONFIG["mandir"]') do |mandir|
      InstallOptions.mandir = mandir
    end
    opts.on('--[no-]check-prereqs', 'Prevents validation of prerequisite libraries', 'Default on') do |prereq|
      InstallOptions.check_prereqs = prereq
    end
    opts.on('--no-batch-files', 'Prevents installation of batch files for windows', 'Default off') do |batch_files|
      InstallOptions.batch_files = false
    end
    opts.on('--quick', 'Performs a quick installation. Only the', 'installation is done.') do |quick|
      InstallOptions.configs = true
      warn "--quick is deprecated. Use --configs"
    end
    opts.separator("")
    opts.on_tail('--help', "Shows this help text.") do
      $stderr.puts opts
      exit
    end

    opts.parse!
  end

  # Mac OS X 10.5 and higher declare bindir
  # /System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin
  # which is not generally where people expect executables to be installed
  # These settings are appropriate defaults for all OS X versions.
  if RUBY_PLATFORM =~ /^universal-darwin[\d\.]+$/
    RbConfig::CONFIG['bindir'] = "/usr/bin"
  end

  # Here we only set $osname if we have opted to check for prereqs.
  # Otherwise facter won't be guaranteed to be present.
  if InstallOptions.check_prereqs
    check_prereqs
    $osname = Facter.value('os.name')
  end

  if not InstallOptions.configdir.nil?
    configdir = InstallOptions.configdir
  elsif $osname == "windows"
    configdir = File.join(ENV['ALLUSERSPROFILE'], "PuppetLabs", "puppet", "etc")
  else
    configdir = "/etc/puppetlabs/puppet"
  end

  if not InstallOptions.codedir.nil?
    codedir = InstallOptions.codedir
  elsif $osname == "windows"
    codedir = File.join(ENV['ALLUSERSPROFILE'], "PuppetLabs", "code")
  else
    codedir = "/etc/puppetlabs/code"
  end

  if not InstallOptions.vardir.nil?
    vardir = InstallOptions.vardir
  elsif $osname == "windows"
    vardir = File.join(ENV['ALLUSERSPROFILE'], "PuppetLabs", "puppet", "cache")
  else
    vardir = "/opt/puppetlabs/puppet/cache"
  end

  if not InstallOptions.publicdir.nil?
    publicdir = InstallOptions.publicdir
  elsif $osname == "windows"
    publicdir = File.join(ENV['ALLUSERSPROFILE'], "PuppetLabs", "puppet", "public")
  else
    publicdir = "/opt/puppetlabs/puppet/public"
  end

  if not InstallOptions.rundir.nil?
    rundir = InstallOptions.rundir
  elsif $osname == "windows"
    rundir = File.join(ENV['ALLUSERSPROFILE'], "PuppetLabs", "puppet", "var", "run")
  else
    rundir = "/var/run/puppetlabs"
  end

  if not InstallOptions.logdir.nil?
    logdir = InstallOptions.logdir
  elsif $osname == "windows"
    logdir = File.join(ENV['ALLUSERSPROFILE'], "PuppetLabs", "puppet", "var", "log")
  else
    logdir = "/var/log/puppetlabs/puppet"
  end

  if not InstallOptions.bindir.nil?
    bindir = InstallOptions.bindir
  else
    bindir = RbConfig::CONFIG['bindir']
  end

  if not InstallOptions.localedir.nil?
    localedir = InstallOptions.localedir
  else
    if $osname == "windows"
      localedir = File.join(ENV['PROGRAMFILES'], "Puppet Labs", "Puppet", "puppet", "share", "locale")
    else
      localedir = "/opt/puppetlabs/puppet/share/locale"
    end
  end

  if not InstallOptions.sitelibdir.nil?
    sitelibdir = InstallOptions.sitelibdir
  else
    sitelibdir = RbConfig::CONFIG["sitelibdir"]
    if sitelibdir.nil?
      sitelibdir = $LOAD_PATH.find { |x| x =~ /site_ruby/ }
      if sitelibdir.nil?
        version = [RbConfig::CONFIG["MAJOR"], RbConfig::CONFIG["MINOR"]].join(".")
        sitelibdir = File.join(RbConfig::CONFIG["libdir"], "ruby", version, "site_ruby")
      elsif sitelibdir !~ Regexp.quote(version)
        sitelibdir = File.join(sitelibdir, version)
      end
    end
  end

  if not InstallOptions.mandir.nil?
    mandir = InstallOptions.mandir
  else
    mandir = RbConfig::CONFIG['mandir']
  end

  # This is the new way forward
  if not InstallOptions.destdir.nil?
    destdir = InstallOptions.destdir
  else
    destdir = ''
  end

  configdir = join(destdir, configdir)
  codedir = join(destdir, codedir)
  vardir = join(destdir, vardir)
  publicdir = join(destdir, publicdir)
  rundir = join(destdir, rundir)
  logdir = join(destdir, logdir)
  bindir = join(destdir, bindir)
  localedir = join(destdir, localedir)
  mandir = join(destdir, mandir)
  sitelibdir = join(destdir, sitelibdir)

  FileUtils.makedirs(configdir) if InstallOptions.configs
  FileUtils.makedirs(codedir)
  FileUtils.makedirs(bindir)
  FileUtils.makedirs(mandir)
  FileUtils.makedirs(sitelibdir)
  FileUtils.makedirs(vardir)
  FileUtils.makedirs(publicdir)
  FileUtils.makedirs(rundir)
  FileUtils.makedirs(logdir)
  FileUtils.makedirs(localedir)

  InstallOptions.site_dir = sitelibdir
  InstallOptions.codedir = codedir
  InstallOptions.config_dir = configdir
  InstallOptions.bin_dir = bindir
  InstallOptions.man_dir = mandir
  InstallOptions.var_dir = vardir
  InstallOptions.public_dir = publicdir
  InstallOptions.run_dir = rundir
  InstallOptions.log_dir = logdir
  InstallOptions.locale_dir = localedir
end

##
# Join two paths. On Windows, dir must be converted to a relative path,
# by stripping the drive letter, but only if the basedir is not empty.
#
def join(basedir, dir)
  return "#{basedir}#{dir[2..-1]}" if $osname == "windows" and basedir.length > 0 and dir.length > 2

  "#{basedir}#{dir}"
end

##
# Install file(s) from ./bin to RbConfig::CONFIG['bindir']. Patch it on the way
# to insert a #! line; on a Unix install, the command is named as expected
# (e.g., bin/rdoc becomes rdoc); the shebang line handles running it. Under
# windows, we add an '.rb' extension and let file associations do their stuff.
def install_binfile(from, op_file, target)
  tmp_file = Tempfile.new('puppet-binfile')

  if not InstallOptions.ruby.nil?
    ruby = InstallOptions.ruby
  else
    ruby = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
  end

  File.open(from) do |ip|
    File.open(tmp_file.path, "w") do |op|
      op.puts "#!#{ruby}" unless $osname == "windows"
      contents = ip.readlines
      contents.shift if contents[0] =~ /^#!/
      op.write contents.join
    end
  end

  if $osname == "windows" && InstallOptions.batch_files
    installed_wrapper = false

    unless File.extname(from) =~ /\.(cmd|bat)/
      if File.exist?("#{from}.bat")
        FileUtils.install("#{from}.bat", File.join(target, "#{op_file}.bat"), mode: 0755, preserve: true, verbose: true)
        installed_wrapper = true
      end

      if File.exist?("#{from}.cmd")
        FileUtils.install("#{from}.cmd", File.join(target, "#{op_file}.cmd"), mode: 0755, preserve: true, verbose: true)
        installed_wrapper = true
      end

      if not installed_wrapper
        tmp_file2 = Tempfile.new('puppet-wrapper')
        cwv = <<-EOS
@echo off
SETLOCAL
if exist "%~dp0environment.bat" (
  call "%~dp0environment.bat" %0 %*
) else (
  SET "PATH=%~dp0;%PATH%"
)
ruby.exe -S -- puppet %*
EOS
        File.open(tmp_file2.path, "w") { |cw| cw.puts cwv }
        FileUtils.install(tmp_file2.path, File.join(target, "#{op_file}.bat"), mode: 0755, preserve: true, verbose: true)

        tmp_file2.unlink
      end
    end
  end
  FileUtils.install(tmp_file.path, File.join(target, op_file), mode: 0755, preserve: true, verbose: true)
  tmp_file.unlink
end

# Change directory into the puppet root so we don't get the wrong files for install.
FileUtils.cd File.dirname(__FILE__) do
  # Set these values to what you want installed.
  configs = glob(%w{conf/puppet.conf conf/hiera.yaml})
  bins  = glob(%w{bin/*})
  man   = glob(%w{man/man[0-9]/*})
  libs  = glob(%w{lib/**/*})
  locales = glob(%w{locales/**/*})

  prepare_installation

  if $osname == "windows"
    windows_bins = glob(%w{ext/windows/*bat})
  end

  do_configs(configs, InstallOptions.config_dir) if InstallOptions.configs
  do_bins(bins, InstallOptions.bin_dir)
  do_bins(windows_bins, InstallOptions.bin_dir, 'ext/windows/') if $osname == "windows" && InstallOptions.batch_files
  do_libs(libs)
  do_locales(locales)
  do_man(man) unless $osname == "windows"
end
