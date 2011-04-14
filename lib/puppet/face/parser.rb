require 'puppet/face'
require 'puppet/parser'

Puppet::Face.define(:parser, '0.0.1') do
 action :validate do
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
