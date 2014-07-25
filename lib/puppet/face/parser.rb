require 'puppet/face'
require 'puppet/parser'

Puppet::Face.define(:parser, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact directly with the parser."

  action :validate do
    summary "Validate the syntax of one or more Puppet manifests."
    arguments "[<manifest>] [<manifest> ...]"
    returns "Nothing, or the first syntax error encountered."
    description <<-'EOT'
      This action validates Puppet DSL syntax without compiling a catalog or
      syncing any resources. If no manifest files are provided, it will
      validate the default site manifest.

      When validating with --parser current, the validation stops after the first
      encountered issue.

      When validating with --parser future, multiple issues per file are reported up
      to the settings of max_error, and max_warnings. The processing stops
      after having reported issues for the first encountered file with errors.
    EOT
    examples <<-'EOT'
      Validate the default site manifest at /etc/puppet/manifests/site.pp:

      $ puppet parser validate

      Validate two arbitrary manifest files:

      $ puppet parser validate init.pp vhost.pp

      Validate from STDIN:

      $ cat init.pp | puppet parser validate
    EOT
    when_invoked do |*args|
      args.pop
      files = args
      if files.empty?
        if not STDIN.tty?
          Puppet[:code] = STDIN.read
          validate_manifest
        else
          manifest = Puppet.lookup(:current_environment).manifest
          files << manifest
          Puppet.notice "No manifest specified. Validating the default manifest #{manifest}"
        end
      end
      missing_files = []
      files.each do |file|
        missing_files << file unless Puppet::FileSystem.exist?(file)
        validate_manifest(file)
      end
      raise Puppet::Error, "One or more file(s) specified did not exist:\n#{missing_files.collect {|f| " " * 3 + f + "\n"}}" unless missing_files.empty?
      nil
    end
  end

  # @api private
  def validate_manifest(manifest = nil)
    env = Puppet.lookup(:current_environment)
    validation_environment = manifest ? env.override_with(:manifest => manifest) : env

    validation_environment.check_for_reparse
    validation_environment.known_resource_types.clear

  rescue => detail
    Puppet.log_exception(detail)
    exit(1)
  end
end
