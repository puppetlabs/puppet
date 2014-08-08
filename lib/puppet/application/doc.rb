require 'puppet/application'

class Puppet::Application::Doc < Puppet::Application
  run_mode :master

  attr_accessor :unknown_args, :manifest

  def preinit
    {:references => [], :mode => :text, :format => :to_markdown }.each do |name,value|
      options[name] = value
    end
    @unknown_args = []
    @manifest = false
  end

  option("--all","-a")
  option("--outputdir OUTPUTDIR","-o")
  option("--verbose","-v")
  option("--debug","-d")
  option("--charset CHARSET")

  option("--format FORMAT", "-f") do |arg|
    method = "to_#{arg}"
    require 'puppet/util/reference'
    if Puppet::Util::Reference.method_defined?(method)
      options[:format] = method
    else
      raise "Invalid output format #{arg}"
    end
  end

  option("--mode MODE", "-m") do |arg|
    require 'puppet/util/reference'
    if Puppet::Util::Reference.modes.include?(arg) or arg.intern==:rdoc
      options[:mode] = arg.intern
    else
      raise "Invalid output mode #{arg}"
    end
  end

  option("--list", "-l") do |arg|
    require 'puppet/util/reference'
    puts Puppet::Util::Reference.references.collect { |r| Puppet::Util::Reference.reference(r).doc }.join("\n")
    exit(0)
  end

  option("--reference REFERENCE", "-r") do |arg|
    options[:references] << arg.intern
  end

  def help
    <<-'HELP'

puppet-doc(8) -- Generate Puppet documentation and references
========

SYNOPSIS
--------
Generates a reference for all Puppet types. Largely meant for internal
Puppet Labs use.


USAGE
-----
puppet doc [-a|--all] [-h|--help] [-l|--list] [-o|--outputdir <rdoc-outputdir>]
  [-m|--mode text|pdf|rdoc] [-r|--reference <reference-name>]
  [--charset <charset>] [<manifest-file>]


DESCRIPTION
-----------
If mode is not 'rdoc', then this command generates a Markdown document
describing all installed Puppet types or all allowable arguments to
puppet executables. It is largely meant for internal use and is used to
generate the reference document available on the Puppet Labs web site.

In 'rdoc' mode, this command generates an html RDoc hierarchy describing
the manifests that are in 'manifestdir' and 'modulepath' configuration
directives. The generated documentation directory is doc by default but
can be changed with the 'outputdir' option.

If the command is run with the name of a manifest file as an argument,
puppet doc will output a single manifest's documentation on stdout.


OPTIONS
-------
* --all:
  Output the docs for all of the reference types. In 'rdoc' mode, this also
  outputs documentation for all resources.

* --help:
  Print this help message

* --outputdir:
  Used only in 'rdoc' mode. The directory to which the rdoc output should
  be written.

* --mode:
  Determine the output mode. Valid modes are 'text', 'pdf' and 'rdoc'. The 'pdf'
  mode creates PDF formatted files in the /tmp directory. The default mode is
  'text'.

* --reference:
  Build a particular reference. Get a list of references by running
  'puppet doc --list'.

* --charset:
  Used only in 'rdoc' mode. It sets the charset used in the html files produced.

* --manifestdir:
  Used only in 'rdoc' mode. The directory to scan for stand-alone manifests.
  If not supplied, puppet doc will use the manifestdir from puppet.conf.

* --modulepath:
  Used only in 'rdoc' mode. The directory or directories to scan for modules.
  If not supplied, puppet doc will use the modulepath from puppet.conf.

* --environment:
  Used only in 'rdoc' mode. The configuration environment from which
  to read the modulepath and manifestdir settings, when reading said settings
  from puppet.conf.


EXAMPLE
-------
    $ puppet doc -r type > /tmp/type_reference.markdown

or

    $ puppet doc --outputdir /tmp/rdoc --mode rdoc /path/to/manifests

or

    $ puppet doc /etc/puppet/manifests/site.pp

or

    $ puppet doc -m pdf -r configuration


AUTHOR
------
Luke Kanies


COPYRIGHT
---------
Copyright (c) 2011 Puppet Labs, LLC Licensed under the Apache 2.0 License

HELP
  end

  def handle_unknown( opt, arg )
    @unknown_args << {:opt => opt, :arg => arg }
    true
  end

  def run_command
    return [:rdoc].include?(options[:mode]) ? send(options[:mode]) : other
  end

  def rdoc
    exit_code = 0
    files = []
    unless @manifest
      env = Puppet.lookup(:current_environment)
      files += env.modulepath
      files << ::File.dirname(env.manifest) if env.manifest != Puppet::Node::Environment::NO_MANIFEST
    end
    files += command_line.args
    Puppet.info "scanning: #{files.inspect}"

    Puppet.settings[:document_all] = options[:all] || false
    begin
      require 'puppet/util/rdoc'
      if @manifest
        Puppet::Util::RDoc.manifestdoc(files)
      else
        options[:outputdir] = "doc" unless options[:outputdir]
        Puppet::Util::RDoc.rdoc(options[:outputdir], files, options[:charset])
      end
    rescue => detail
      Puppet.log_exception(detail, "Could not generate documentation: #{detail}")
      exit_code = 1
    end
    exit exit_code
  end

  def other
    text = ""
    with_contents = options[:references].length <= 1
    exit_code = 0
    require 'puppet/util/reference'
    options[:references].sort { |a,b| a.to_s <=> b.to_s }.each do |name|
      raise "Could not find reference #{name}" unless section = Puppet::Util::Reference.reference(name)

      begin
        # Add the per-section text, but with no ToC
        text += section.send(options[:format], with_contents)
      rescue => detail
        Puppet.log_exception(detail, "Could not generate reference #{name}: #{detail}")
        exit_code = 1
        next
      end
    end

    text += Puppet::Util::Reference.footer unless with_contents # We've only got one reference

    if options[:mode] == :pdf
      Puppet::Util::Reference.pdf(text)
    else
      puts text
    end

    exit exit_code
  end

  def setup
    # sole manifest documentation
    if command_line.args.size > 0
      options[:mode] = :rdoc
      @manifest = true
    end

    if options[:mode] == :rdoc
      setup_rdoc
    else
      setup_reference
    end

    setup_logging
  end

  def setup_reference
    if options[:all]
      # Don't add dynamic references to the "all" list.
      require 'puppet/util/reference'
      options[:references] = Puppet::Util::Reference.references.reject do |ref|
        Puppet::Util::Reference.reference(ref).dynamic?
      end
    end

    options[:references] << :type if options[:references].empty?
  end

  def setup_rdoc(dummy_argument=:work_arround_for_ruby_GC_bug)
    # consume the unknown options
    # and feed them as settings
    if @unknown_args.size > 0
      @unknown_args.each do |option|
        # force absolute path for modulepath when passed on commandline
        if option[:opt]=="--modulepath" or option[:opt] == "--manifestdir"
          option[:arg] = option[:arg].split(::File::PATH_SEPARATOR).collect { |p| ::File.expand_path(p) }.join(::File::PATH_SEPARATOR)
        end
        Puppet.settings.handlearg(option[:opt], option[:arg])
      end
    end
  end

  def setup_logging
  # Handle the logging settings.
    if options[:debug]
      Puppet::Util::Log.level = :debug
    elsif options[:verbose]
      Puppet::Util::Log.level = :info
    else
      Puppet::Util::Log.level = :warning
    end

    Puppet::Util::Log.newdestination(:console)
  end
end
