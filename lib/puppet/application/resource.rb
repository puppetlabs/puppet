# frozen_string_literal: true

require_relative '../../puppet/application'

class Puppet::Application::Resource < Puppet::Application
  environment_mode :not_required

  attr_accessor :host, :extra_params

  def preinit
    @extra_params = [:provider]
  end

  option("--debug", "-d")
  option("--verbose", "-v")
  option("--edit", "-e")
  option("--to_yaml", "-y")

  option("--types", "-t") do |_arg|
    env = Puppet.lookup(:environments).get(Puppet[:environment]) || create_default_environment
    types = []
    Puppet::Type.typeloader.loadall(env)
    Puppet::Type.eachtype do |t|
      next if t.name == :component

      types << t.name.to_s
    end
    puts types.sort
    exit(0)
  end

  option("--param PARAM", "-p") do |arg|
    @extra_params << arg.to_sym
  end

  def summary
    _("The resource abstraction layer shell")
  end

  def help
    <<~HELP

      puppet-resource(8) -- #{summary}
      ========

      SYNOPSIS
      --------
      Uses the Puppet RAL to directly interact with the system.


      USAGE
      -----
      puppet resource [-h|--help] [-d|--debug] [-v|--verbose] [-e|--edit]
        [-p|--param <parameter>] [-t|--types] [-y|--to_yaml] <type>
        [<name>] [<attribute>=<value> ...]


      DESCRIPTION
      -----------
      This command provides simple facilities for converting current system
      state into Puppet code, along with some ability to modify the current
      state using Puppet's RAL.

      By default, you must at least provide a type to list, in which case
      puppet resource will tell you everything it knows about all resources of
      that type. You can optionally specify an instance name, and puppet
      resource will only describe that single instance.

      If given a type, a name, and a series of <attribute>=<value> pairs,
      puppet resource will modify the state of the specified resource.
      Alternately, if given a type, a name, and the '--edit' flag, puppet
      resource will write its output to a file, open that file in an editor,
      and then apply the saved file as a Puppet transaction.


      OPTIONS
      -------
      Note that any setting that's valid in the configuration
      file is also a valid long argument. For example, 'ssldir' is a valid
      setting, so you can specify '--ssldir <directory>' as an
      argument.

      See the configuration file documentation at
      https://puppet.com/docs/puppet/latest/configuration.html for the
      full list of acceptable parameters. A commented list of all
      configuration options can also be generated by running puppet with
      '--genconfig'.

      * --debug:
        Enable full debugging.

      * --edit:
        Write the results of the query to a file, open the file in an editor,
        and read the file back in as an executable Puppet manifest.

      * --help:
        Print this help message.

      * --param:
        Add more parameters to be outputted from queries.

      * --types:
        List all available types.

      * --verbose:
        Print extra information.

      * --to_yaml:
        Output found resources in yaml format, suitable to use with Hiera and
        create_resources.

      EXAMPLE
      -------
      This example uses `puppet resource` to return a Puppet configuration for
      the user `luke`:

          $ puppet resource user luke
          user { 'luke':
           home => '/home/luke',
           uid => '100',
           ensure => 'present',
           comment => 'Luke Kanies,,,',
           gid => '1000',
           shell => '/bin/bash',
           groups => ['sysadmin','audio','video','puppet']
          }


      AUTHOR
      ------
      Luke Kanies


      COPYRIGHT
      ---------
      Copyright (c) 2011 Puppet Inc., LLC Licensed under the Apache 2.0 License

    HELP
  end

  def main
    # If the specified environment does not exist locally, fall back to the default (production) environment
    env = Puppet.lookup(:environments).get(Puppet[:environment]) || create_default_environment

    Puppet.override(:current_environment => env, :loaders => Puppet::Pops::Loaders.new(env)) do
      type, name, params = parse_args(command_line.args)

      raise _("Editing with Yaml output is not supported") if options[:edit] and options[:to_yaml]

      resources = find_or_save_resources(type, name, params)

      if options[:to_yaml]
        data = resources.map do |resource|
          resource.prune_parameters(:parameters_to_include => @extra_params).to_hiera_hash
        end.inject(:merge!)
        text = YAML.dump(type.downcase => data)
      else
        text = resources.map do |resource|
          resource.prune_parameters(:parameters_to_include => @extra_params).to_manifest.force_encoding(Encoding.default_external)
        end.join("\n")
      end

      options[:edit] ?
        handle_editing(text) :
        (puts text)
    end
  end

  def setup
    Puppet::Util::Log.newdestination(:console)
    set_log_level
  end

  private

  def local_key(type, name)
    [type, name].join('/')
  end

  def handle_editing(text)
    require 'tempfile'
    # Prefer the current directory, which is more likely to be secure
    # and, in the case of interactive use, accessible to the user.
    tmpfile = Tempfile.new('x2puppet', Dir.pwd, :encoding => Encoding::UTF_8)
    begin
      # sync write, so nothing buffers before we invoke the editor.
      tmpfile.sync = true
      tmpfile.puts text

      # edit the content
      system(ENV["EDITOR"] || 'vi', tmpfile.path)

      # ...and, now, pass that file to puppet to apply.  Because
      # many editors rename or replace the original file we need to
      # feed the pathname, not the file content itself, to puppet.
      system('puppet apply -v ' + tmpfile.path)
    ensure
      # The temporary file will be safely removed.
      tmpfile.close(true)
    end
  end

  def parse_args(args)
    type = args.shift or raise _("You must specify the type to display")
    Puppet::Type.type(type) or raise _("Could not find type %{type}") % { type: type }
    name = args.shift
    params = {}
    args.each do |setting|
      if setting =~ /^(\w+)=(.+)$/
        params[$1] = $2
      else
        raise _("Invalid parameter setting %{setting}") % { setting: setting }
      end
    end

    [type, name, params]
  end

  def create_default_environment
    Puppet.debug("Specified environment '#{Puppet[:environment]}' does not exist on the filesystem, defaulting to 'production'")
    Puppet[:environment] = :production
    basemodulepath = Puppet::Node::Environment.split_path(Puppet[:basemodulepath])
    modulepath = Puppet[:modulepath]
    modulepath = (modulepath.nil? || modulepath.empty?) ? basemodulepath : Puppet::Node::Environment.split_path(modulepath)
    Puppet::Node::Environment.create(Puppet[:environment], modulepath, Puppet::Node::Environment::NO_MANIFEST)
  end

  def find_or_save_resources(type, name, params)
    key = local_key(type, name)

    Puppet.override(stringify_rich: true) do
      if name
        if params.empty?
          [ Puppet::Resource.indirection.find( key ) ]
        else
          resource = Puppet::Resource.new(type, name, :parameters => params)

          # save returns [resource that was saved, transaction log from applying the resource]
          save_result, report = Puppet::Resource.indirection.save(resource, key)
          status = report.resource_statuses[resource.ref]
          raise "Failed to manage resource #{resource.ref}" if status&.failed?

          [ save_result ]
        end
      else
        if type == "file"
          raise _("Listing all file instances is not supported.  Please specify a file or directory, e.g. puppet resource file /etc")
        end

        Puppet::Resource.indirection.search(key, {})
      end
    end
  end
end
