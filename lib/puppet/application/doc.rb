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
      raise _("Invalid output format %{arg}") % { arg: arg }
    end
  end

  option("--mode MODE", "-m") do |arg|
    require 'puppet/util/reference'
    if Puppet::Util::Reference.modes.include?(arg) or arg.intern==:rdoc
      options[:mode] = arg.intern
    else
      raise _("Invalid output mode %{arg}") % { arg: arg }
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

  def summary
    _("Generate Puppet references")
  end

  def help
    <<-HELP

puppet-doc(8) -- #{summary}
========

SYNOPSIS
--------
Generates a reference for all Puppet types. Largely meant for internal
Puppet Inc. use. (Deprecated)


USAGE
-----
puppet doc [-h|--help] [-l|--list]
  [-r|--reference <reference-name>]


DESCRIPTION
-----------
This deprecated command generates a Markdown document to stdout
describing all installed Puppet types or all allowable arguments to
puppet executables. It is largely meant for internal use and is used to
generate the reference document available on the Puppet Inc. web site.

For Puppet module documentation (and all other use cases) this command
has been superseded by the "puppet-strings"
module - see https://github.com/puppetlabs/puppetlabs-strings for more information.

This command (puppet-doc) will be removed once the
puppetlabs internal documentation processing pipeline is completely based
on puppet-strings.

OPTIONS
-------

* --help:
  Print this help message

* --reference:
  Build a particular reference. Get a list of references by running
  'puppet doc --list'.


EXAMPLE
-------
    $ puppet doc -r type > /tmp/type_reference.markdown


AUTHOR
------
Luke Kanies


COPYRIGHT
---------
Copyright (c) 2011 Puppet Inc., LLC Licensed under the Apache 2.0 License

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
    Puppet.info _("scanning: %{files}") % { files: files.inspect }

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
      Puppet.log_exception(detail, _("Could not generate documentation: %{detail}") % { detail: detail })
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
      raise _("Could not find reference %{name}") % { name: name } unless section = Puppet::Util::Reference.reference(name)

      begin
        # Add the per-section text, but with no ToC
        text += section.send(options[:format], with_contents)
      rescue => detail
        Puppet.log_exception(detail, _("Could not generate reference %{name}: %{detail}") % { name: name, detail: detail })
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

  def setup_rdoc
    # consume the unknown options
    # and feed them as settings
    if @unknown_args.size > 0
      @unknown_args.each do |option|
        # force absolute path for modulepath when passed on commandline
        if option[:opt]=="--modulepath"
          option[:arg] = option[:arg].split(::File::PATH_SEPARATOR).collect { |p| ::File.expand_path(p) }.join(::File::PATH_SEPARATOR)
        end
        Puppet.settings.handlearg(option[:opt], option[:arg])
      end
    end
  end

  def setup_logging
    Puppet::Util::Log.level = :warning

    set_log_level

    Puppet::Util::Log.newdestination(:console)
  end
end
