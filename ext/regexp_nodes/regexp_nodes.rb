#!/usr/bin/env ruby

# = Synopsis
# This is an external node classifier script, after
# https://docs.puppetlabs.com/guides/external_nodes.html
#
# = Usage
# regexp_nodes.rb <host>
#
# = Description
# This classifier implements filesystem autoloading: It looks through classes,
# parameters, and environment subdirectories, looping through each file it 
# finds.  Each file's contents are a regexp-per-line which, if they match the 
# hostname passed to the program as ARGV[0], sets a class, parameter value 
# or environment named the same thing as the file itself. At the end, the
# resultant data structure is returned back to the puppet master process as 
# yaml.
#
# = Caveats
# Since the files are read in directory order, multiple matches for a given
# hostname in the parameters/ and environment/ subdirectories will return the
# last-read value.  (Multiple classes/ matches don't cause a problem; the 
# class is either incuded or it isn't)
#
# Unmatched hostnames in any of the environment/ files will cause 'production'
# to be emitted; be aware of the complexity surrounding the interaction between
# ENC and environments as discussed in https://projects.puppetlabs.com/issues/3910
#
# = Examples
# Based on the example files in the classes/ and parameters/ subdirectories
# in the distribution, classes/database will set the 'database' class for 
# hosts matching %r{db\d{2}} (that is, 'db' followed by two digits) or with 
# 'mysql' anywhere in the hostname.  Similarly, hosts beginning with 'www' or 
# 'web' or the hostname 'leterel' (my workstation) will be assigned the 
# 'webserver' class.
#
# Under parameters/ there is one subdirectory 'service' which
# sets the a parameter called 'service' to the value 'prod' for production
# hosts (whose hostnames always end with a three-digit code), 'qa' for
# anything that starts with 'qa-' 'qa2-' or 'qa3-', and 'sandbox' for any
# development machines whose hostnames start with 'dev-'.
#
# In the environment/ subdirectory, any hosts matching '^dev-' and a single
# production host which serves as 'canary in the coal mine' will be put into
# the development environment 
#
# = Author
# Eric Sorenson <eric@explosive.net>

# we need yaml or there's not much point in going on
require 'yaml'

# Sets are like arrays but automatically de-duplicate elements
require 'set'

# set up some syslog logging
require 'syslog'
Syslog.open('extnodes', Syslog::LOG_PID | Syslog::LOG_NDELAY, Syslog::LOG_DAEMON)
# change this to LOG_UPTO(Sysslog::LOG_DEBUG) if you want to see everything
# but remember your syslog.conf needs to match this or messages will be filtered
Syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_INFO)

# Helper method to log to syslog; we log at level debug if no level is specified
# since those are the most frequent calls to this method
def log(message,level=:debug)
  Syslog.send(level,message)
end


# set our workingdir to be the directory we're executed from, regardless
# of parent's cwd, symlinks, etc. via handy Pathname.realpath method
require 'pathname'
p = Pathname.new(File.dirname(__FILE__))
WORKINGDIR = "#{p.realpath}"

# This class holds all the methods for creating and accessing the properties
# of an external node. There are really only two public methods: initialize
# and a special version of to_yaml

class ExternalNode
  # Make these instance variables get/set-able with eponymous methods
  attr_accessor :classes, :parameters, :environment, :hostname

  # initialize takes three arguments:
  # hostname:: usually passed in via ARGV[0] but it could be anything
  # classdir:: directory under WORKINGDIR to look for files named after
  # classes
  # parameterdir:: directory under WORKINGDIR to look for directories to set
  # parameters
  def initialize(hostname, classdir = 'classes/', parameterdir = 'parameters/', environmentdir = 'environment/')
    # instance variables that contain the lists of classes and parameters
    @classes = Set.new
    @parameters = Hash.new("unknown")  # sets a default value of "unknown"
    @environment = "production"

    self.parse_argv(hostname)
    self.match_classes("#{WORKINGDIR}/#{classdir}")
    self.match_parameters("#{WORKINGDIR}/#{parameterdir}")
    self.match_environment("#{WORKINGDIR}/#{environmentdir}")
  end

  # private method called by initialize which sanity-checks our hostname.
  # good candidate for overriding in a subclass if you need different checks
  def parse_argv(hostname)
    if hostname =~ /^([-\w]+?)\.([-\w\.]+)/  # non-greedy up to the first . is hostname
      @hostname = $1
    elsif hostname =~ /^([-\w]+)$/     # sometimes puppet's @name is just a name
      @hostname = hostname
      log("got shortname for [#{hostname}]")
    else
      log("didn't receive parsable hostname, got: [#{hostname}]",:err)
      exit(1)
    end
  end

  # to_yaml massages a copy of the object and outputs clean yaml so we don't
  # feed weird things back to puppet []<
  def to_yaml
    classes = self.classes.to_a
    if self.parameters.empty? # otherwise to_yaml prints "parameters: {}"
      parameters = nil
    else
      parameters = self.parameters
    end
    ({ 'classes' => classes, 'parameters' => parameters, 'environment' => environment}).to_yaml
  end

  # Private method that expects an absolute path to a file and a string to
  # match - it returns true if the string was matched by any of the lines in
  # the file
  def matched_in_patternfile?(filepath, matchthis)

    patternlist = []

    begin
      open(filepath).each do |l|
        l.chomp!

        next if l =~ /^$/
        next if l =~ /^#/

        if l =~ /^\s*(\S+)/
          m = Regexp.last_match
          log("found a non-comment line, transforming [#{l}] into [#{m[1]}]")
          l.gsub!(l,m[1])
        else
          next l
        end

        pattern = %r{#{l}}
        patternlist <<  pattern
        log("appending [#{pattern}] to patternlist for [#{filepath}]")
      end
    rescue StandardError
      log("Problem reading #{filepath}: #{$!}",:err)
      exit(1)
    end

    log("list of patterns for #{filepath}: #{patternlist}")

    if matchthis =~ Regexp.union(patternlist)
      log("matched #{$~.to_s} in #{matchthis}, returning true")
      return true

    else  # hostname didn't match anything in patternlist
      log("#{matchthis} unmatched, returning false")
      return nil
    end

  end # def

  # private method - takes a path to look for files, iterates through all
  # readable, regular files it finds, and matches this instance's @hostname
  # against each line; if any match, the class will be set for this node.
  def match_classes(fullpath)
    Dir.foreach(fullpath) do |patternfile|
      filepath = "#{fullpath}/#{patternfile}"
      next unless File.file?(filepath) and
        File.readable?(filepath)
        next if patternfile =~ /^\./
      log("Attempting to match [#{@hostname}] in [#{filepath}]")
      if matched_in_patternfile?(filepath,@hostname)
        @classes << patternfile.to_s
        log("Appended #{patternfile.to_s} to classes instance variable")
      end
    end
  end

  # match_environment is similar to match_classes but it overwrites 
  # any previously set value (usually just the default, 'production')
  # with a match
  def match_environment(fullpath)
    Dir.foreach(fullpath) do |patternfile|
      filepath = "#{fullpath}/#{patternfile}"
      next unless File.file?(filepath) and
        File.readable?(filepath)
        next if patternfile =~ /^\./
      log("Attempting to match [#{@hostname}] in [#{filepath}]")
      if matched_in_patternfile?(filepath,@hostname)
        @environment = patternfile.to_s
        log("Wrote #{patternfile.to_s} to environment instance variable")
      end
    end
  end


  # Parameters are handled slightly differently; we make another level of
  # directories to get the parameter name, then use the names of the files
  # contained in there for the values of those parameters.
  #
  # ex: cat ./parameters/service/production
  # ^prodweb
  # would set parameters["service"] = "production" for prodweb001
  def match_parameters(fullpath)
    Dir.foreach(fullpath) do |parametername|

      filepath = "#{fullpath}/#{parametername}"
      next if File.basename(filepath) =~ /^\./   # skip over dotfiles

      next unless File.directory?(filepath) and
        File.readable?(filepath)        # skip over non-directories

      log("Considering contents of #{filepath}")

      Dir.foreach("#{filepath}") do |patternfile|
        secondlevel = "#{filepath}/#{patternfile}"
        log("Found parameters patternfile at #{secondlevel}")
        next unless File.file?(secondlevel) and
          File.readable?(secondlevel)
        log("Attempting to match [#{@hostname}] in [#{secondlevel}]")
        if matched_in_patternfile?(secondlevel, @hostname)
          @parameters[ parametername.to_s ] = patternfile.to_s
          log("Set @parameters[#{parametername.to_s}] = #{patternfile.to_s}")
        end
      end
    end
  end

end

# Logic for local hacks that don't fit neatly into the autoloading model can
# happen as we initialize a subclass
class MyExternalNode < ExternalNode

  def initialize(hostname, classdir = 'classes/', parameterdir = 'parameters/')

    super

    # Set "hostclass" parameter based on hostname,
    # stripped of leading environment prefix and numeric suffix
    if @hostname =~ /^(\w*?)-?(\D+)(\d{2,3})$/
      match = Regexp.last_match

      hostclass = match[2]
      log("matched hostclass #{hostclass}")
      @parameters[ "hostclass" ] = hostclass
    else
      log("couldn't figure out class from #{@hostname}",:warning)

    end
  end

end


# Here we begin actual execution by calling methods defined above

mynode = MyExternalNode.new(ARGV[0])

puts mynode.to_yaml
