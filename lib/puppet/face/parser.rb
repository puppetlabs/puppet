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
    EOT
    examples <<-'EOT'
      Validate the default site manifest at /etc/puppet/manifests/site.pp:

      $ puppet parser validate

      Validate two arbitrary manifest files:

      $ puppet parser validate init.pp vhost.pp
    EOT
    when_invoked do |*args|
      args.pop
      files = args
      if files.empty?
        files << Puppet[:manifest]
        Puppet.notice "No manifest specified. Validating the default manifest #{Puppet[:manifest]}"
      end
      files.each do |file|
        Puppet[:manifest] = file
        Puppet::Node::Environment.new(Puppet[:environment]).known_resource_types.clear
      end
      nil
    end
  end
end
