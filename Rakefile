# Rakefile for Puppet

begin
  require 'rubygems'
  require 'rake/gempackagetask'
rescue Exception
  nil
end

require 'rake/clean'
require 'rake/testtask'

#require 'rake/rdoctask'
#CLEAN.include('**/*.o')
#CLOBBER.include('doc/*')

def announce(msg='')
  STDERR.puts msg
end


# Determine the current version

if `ruby -Ilib ./bin/puppet --version` =~ /\S+$/
  CURRENT_VERSION = $&
else
  CURRENT_VERSION = "0.0.0"
end

if ENV['REL']
  PKG_VERSION = ENV['REL']
else
  PKG_VERSION = CURRENT_VERSION
end


# The default task is run if rake is given no explicit arguments.

desc "Default Task"
task :default => :alltests

# Test Tasks ---------------------------------------------------------

task :u => :unittests
task :a => :alltests

Rake::TestTask.new(:alltests) do |t|
  t.test_files = FileList['test/tc*.rb']
  t.warning = true
  t.verbose = false
end

Rake::TestTask.new(:unittests) do |t|
  t.test_files = FileList['test/test']
  t.warning = true
  t.verbose = false
end

# SVN Tasks ----------------------------------------------------------
# ... none.

# Install rake using the standard install.rb script.

desc "Install the application"
task :install do
  ruby "install.rb"
end

# Create a task to build the RDOC documentation tree.

#rd = Rake::RDocTask.new("rdoc") { |rdoc|
#  rdoc.rdoc_dir = 'html'
#  rdoc.template = 'css2'
#  rdoc.title    = "Puppet"
#  rdoc.options << '--line-numbers' << '--inline-source' << '--main' << 'README'
#  rdoc.rdoc_files.include('README', 'LICENSE', 'TODO', 'CHANGELOG')
#  rdoc.rdoc_files.include('lib/**/*.rb', 'doc/**/*.rdoc')
#}

# ====================================================================
# Create a task that will package the Rake software into distributable
# tar, zip and gem files.

PKG_FILES = FileList[
  'install.rb',
  '[A-Z]*',
  'lib/**/*.rb',
  'test/**/*.rb',
  'bin/**/*',
  'examples/**/*'
]
PKG_FILES.delete_if {|item| item.include?(".svn")}

if ! defined?(Gem)
  puts "Package Target requires RubyGEMs"
else
  spec = Gem::Specification.new do |s|
    
    #### Basic information.

    s.name = 'puppet'
    s.version = PKG_VERSION
    s.summary = "Puppet is a server configuration management tool."
    s.description = <<-EOF
      Puppet is a declarative language for expressing system configuration,
      a client and server for distributing it, and a library for realizing 
      the configuration.
    EOF
    s.platform = Gem::Platform::RUBY

    #### Dependencies and requirements.

    s.add_dependency('facter', '>= 1.0.0')
    #s.requirements << ""

    s.files = PKG_FILES.to_a

    #### Load-time details: library and application (you will need one or both).

    s.require_path = 'lib'                         # Use these for libraries.

    s.bindir = "bin"                               # Use these for applications.
    s.executables = ["puppet", "puppetd", "puppetmasterd", "puppetdoc",
                     "puppetca"]
    s.default_executable = "puppet"
    s.autorequire = 'puppet'

    #### Documentation and testing.

    s.has_rdoc = false
    #s.extra_rdoc_files = rd.rdoc_files.reject { |fn| fn =~ /\.rb$/ }.to_a
    #s.rdoc_options <<
    #  '--title' <<  'Puppet - Configuration Management' <<
    #  '--main' << 'README' <<
    #  '--line-numbers'
    s.test_file = "test/test"
 
    #### Signing key and cert chain
    #s.signing_key = '/..../gem-private_key.pem'
    #s.cert_chain = ['gem-public_cert.pem']

    #### Author and project details.

    s.author = "Luke Kanies"
    s.email = "dev@reductivelabs.com"
    s.homepage = "http://reductivelabs.com/projects/puppet"
    #s.rubyforge_project = "puppet"
  end

  Rake::GemPackageTask.new(spec) do |pkg|
    #pkg.need_zip = true
    pkg.need_tar = true
  end
end

# Misc tasks =========================================================

#ARCHIVEDIR = '/tmp'

#task :archive => [:package] do
#  cp FileList["pkg/*.tgz", "pkg/*.zip", "pkg/*.gem"], ARCHIVEDIR
#end

# Define an optional publish target in an external file.  If the
# publish.rf file is not found, the publish targets won't be defined.

#load "publish.rf" if File.exist? "publish.rf"

# Support Tasks ------------------------------------------------------

def egrep(pattern)
  Dir['**/*.rb'].each do |fn|
    count = 0
    open(fn) do |f|
      while line = f.gets
	count += 1
	if line =~ pattern
	  puts "#{fn}:#{count}:#{line}"
	end
      end
    end
  end
end

desc "Look for TODO and FIXME tags in the code"
task :todo do
  egrep "/#.*(FIXME|TODO|TBD)/"
end

#desc "Look for Debugging print lines"
#task :dbg do
#  egrep /\bDBG|\bbreakpoint\b/
#end

#desc "List all ruby files"
#task :rubyfiles do 
#  puts Dir['**/*.rb'].reject { |fn| fn =~ /^pkg/ }
#  puts Dir['**/bin/*'].reject { |fn| fn =~ /svn|(~$)|(\.rb$)/ }
#end

# --------------------------------------------------------------------
# Creating a release

desc "Make a new release"
task :release => [
  :prerelease,
  :clobber,
  :alltests,
  :update_version,
  :package,
  :tag] do
  
  announce 
  announce "**************************************************************"
  announce "* Release #{PKG_VERSION} Complete."
  announce "* Packages ready to upload."
  announce "**************************************************************"
  announce 
end

# Validate that everything is ready to go for a release.
task :prerelease do
  announce 
  announce "**************************************************************"
  announce "* Making RubyGem Release #{PKG_VERSION}"
  announce "* (current version #{CURRENT_VERSION})"
  announce "**************************************************************"
  announce  

  # Is a release number supplied?
  unless ENV['REL']
    fail "Usage: rake release REL=x.y.z [REUSE=tag_suffix]"
  end

  # Is the release different than the current release.
  # (or is REUSE set?)
  if PKG_VERSION == CURRENT_VERSION && ! ENV['REUSE']
    fail "Current version is #{PKG_VERSION}, must specify REUSE=tag_suffix to reuse version"
  end

  # Are all source files checked in?
  if ENV['RELTEST']
    announce "Release Task Testing, skipping checked-in file test"
  else
    announce "Checking for unchecked-in files..."
    data = `svn -q update`
    unless data =~ /^$/
      fail "SVN update is not clean ... do you have unchecked-in files?"
    end
    announce "No outstanding checkins found ... OK"
  end
end

task :update_version => [:prerelease] do
  if PKG_VERSION == CURRENT_VERSION
    announce "No version change ... skipping version update"
  else
    announce "Updating Puppet version to #{PKG_VERSION}"
    open("lib/puppet.rb") do |rakein|
      open("lib/puppet.rb.new", "w") do |rakeout|
	rakein.each do |line|
	  if line =~ /^PUPPETVERSION\s*=\s*/
	    rakeout.puts "PUPPETVERSION = '#{PKG_VERSION}'"
	  else
	    rakeout.puts line
	  end
	end
      end
    end
    mv "lib/puppet.rb.new", "lib/puppet.rb"
    if ENV['RELTEST']
      announce "Release Task Testing, skipping commiting of new version"
    else
      sh %{svn commit -m "Updated to version #{PKG_VERSION}" lib/puppet.rb}
    end
  end
end

desc "Tag all the SVN files with the latest release number (REL=x.y.z)"
task :tag => [:prerelease] do
  reltag = "REL_#{PKG_VERSION.gsub(/\./, '_')}"
  reltag << ENV['REUSE'].gsub(/\./, '_') if ENV['REUSE']
  announce "Tagging SVN copy with [#{reltag}]"
  if ENV['RELTEST']
    announce "Release Task Testing, skipping SVN tagging"
  else
    #sh %{svn copy ../trunk/ ../tags/#{reltag}}
  end
end

