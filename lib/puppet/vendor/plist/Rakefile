##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Based heavily on Geoffrey Grosenbach's Rakefile for gruff. #
# Includes whitespace-fixing task based on code from Typo.   #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'fileutils'
require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

$:.unshift(File.dirname(__FILE__) + "/lib")
require 'plist'

PKG_NAME      = 'plist'
PKG_VERSION   = Plist::VERSION
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

RUBYFORGE_PROJECT = "plist"
RUBYFORGE_USER    = ENV['RUBYFORGE_USER']

TEST_FILES    = Dir.glob('test/test_*').delete_if { |item| item.include?( "\.svn" ) }
TEST_ASSETS   = Dir.glob('test/assets/*').delete_if { |item| item.include?( "\.svn" ) }
LIB_FILES     = Dir.glob('lib/**/*').delete_if { |item| item.include?( "\.svn" ) }
RELEASE_FILES = [ "Rakefile", "README", "MIT-LICENSE", "docs/USAGE" ] + LIB_FILES + TEST_FILES + TEST_ASSETS

task :default => [ :test ]
# Run the unit tests
Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'test/test_*.rb'
  t.verbose = true
}

desc "Clean pkg, coverage, and rdoc; remove .bak files"
task :clean => [ :clobber_rdoc, :clobber_package, :clobber_coverage ] do
  puts cmd = "find . -type f -name *.bak -delete"
  `#{cmd}`
end

task :clobber_coverage do
  puts cmd = "rm -rf coverage"
  `#{cmd}`
end

desc "Generate coverage analysis with rcov (requires rcov to be installed)"
task :rcov => [ :clobber_coverage ] do
  puts cmd = "rcov -Ilib --xrefs -T test/*.rb"
  puts `#{cmd}`
end

desc "Strip trailing whitespace and fix newlines for all release files"
task :fix_whitespace => [ :clean ] do
  RELEASE_FILES.reject {|i| i =~ /assets/}.each do |filename|
    next if File.directory? filename

    File.open(filename) do |file|
      newfile = ''
      needs_love = false

      file.readlines.each_with_index do |line, lineno|
        if line =~ /[ \t]+$/
          needs_love = true
          puts "#{filename}: trailing whitespace on line #{lineno}"
          line.gsub!(/[ \t]*$/, '')
        end

        if line.chomp == line
          needs_love = true
          puts "#{filename}: no newline on line #{lineno}"
          line << "\n"
        end

        newfile << line
      end

      if needs_love
        tempname = "#{filename}.new"

        File.open(tempname, 'w').write(newfile)
        File.chmod(File.stat(filename).mode, tempname)

        FileUtils.ln filename, "#{filename}.bak"
        FileUtils.ln tempname, filename, :force => true
        File.unlink(tempname)
      end
    end
  end
end

desc "Copy documentation to rubyforge"
task :update_rdoc => [ :rdoc ] do
  Rake::SshDirPublisher.new("#{RUBYFORGE_USER}@rubyforge.org", "/var/www/gforge-projects/#{RUBYFORGE_PROJECT}", "rdoc").upload
end

# Genereate the RDoc documentation
Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = "All-purpose Property List manipulation library"
  rdoc.options << '-SNmREADME'
  rdoc.template = "docs/jamis-template.rb"
  rdoc.rdoc_files.include('README', 'MIT-LICENSE', 'CHANGELOG')
  rdoc.rdoc_files.include Dir.glob('docs/**').delete_if {|f| f.include? 'jamis' }
  rdoc.rdoc_files.include('lib/**')
}

# Create compressed packages
spec = Gem::Specification.new do |s|
  s.name    = PKG_NAME
  s.version = PKG_VERSION

  s.summary     = "All-purpose Property List manipulation library."
  s.description = <<-EOD
Plist is a library to manipulate Property List files, also known as plists.  It can parse plist files into native Ruby data structures as well as generating new plist files from your Ruby objects.
EOD

  s.authors  = "Ben Bleything and Patrick May"
  s.homepage = "http://plist.rubyforge.org"

  s.rubyforge_project = RUBYFORGE_PROJECT

  s.has_rdoc = true

  s.files      = RELEASE_FILES
  s.test_files = TEST_FILES

  s.autorequire = 'plist'
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end
