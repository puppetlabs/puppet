# encoding: UTF-8
require 'pathname'

Puppet::Face.define(:module, '1.0.0') do
  action(:skeleton) do
    summary "Manage your skeleton files for modules."
    description <<-EOT
      Manage your skeleton files that are used to generate modules.
    EOT

    returns "A list of your current skeleton modules"

    examples <<-'EOT'
      Lists all of your current module skeletons:

      $ puppet module skeletons
      Fetching your skeletons...
        Default skeleton: /var/lib/puppet/module_tool/skeleton/templates/generator
        Custom skeletons: /home/puppet/.puppet/var/puppet-module/skeleton

    EOT

    when_invoked do |options|
      Puppet::ModuleTool.set_option_defaults options

      skeleton_wrangler = Puppet::ModuleTool::Applications::SkeletonWrangler.new(options)

      skeleton_wrangler.run
    end

    when_rendering :console do |return_value|
      return_value.map {|f| "#{f[0].to_s}: #{f[1]}" }.join("\n")
    end
  end
end
