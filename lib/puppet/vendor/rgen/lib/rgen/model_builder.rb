require 'rgen/model_builder/builder_context'
require 'rgen/util/method_delegation'
#require 'ruby-prof'

module RGen
  
module ModelBuilder

  def self.build(package, env=nil, builderMethodsModule=nil, &block)
    resolver = ReferenceResolver.new
    bc = BuilderContext.new(package, builderMethodsModule, resolver, env)
    contextModule = eval("Module.nesting", block.binding).first
    Util::MethodDelegation.registerDelegate(bc, contextModule, "const_missing")
    BuilderContext.currentBuilderContext = bc
    begin
    #RubyProf.start
      bc.instance_eval(&block)
    #prof = RubyProf.stop
    #File.open("profile_flat.txt","w+") do |f|
    #  RubyProf::FlatPrinter.new(prof).print(f, 0)
    # end
    ensure
      BuilderContext.currentBuilderContext = nil
    end
    Util::MethodDelegation.unregisterDelegate(bc, contextModule, "const_missing")
    #puts "Resolving..."
    resolver.resolve(bc.toplevelElements)
    bc.toplevelElements
  end    
end

end
