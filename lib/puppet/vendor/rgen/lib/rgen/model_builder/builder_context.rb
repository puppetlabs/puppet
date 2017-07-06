require 'rgen/ecore/ecore_ext'
require 'rgen/model_builder/reference_resolver'

module RGen
  
module ModelBuilder
  
class BuilderContext
  attr_reader :toplevelElements
  
  def initialize(package, extensionsModule, resolver, env=nil)
    package = package.ecore unless package.is_a?(RGen::ECore::EPackage)
    raise "First argument must be a metamodel package" \
      unless package.is_a?(RGen::ECore::EPackage)
    @rootPackage, @env = package, env
    @commandResolver = CommandResolver.new(package, extensionsModule, self)
    @package = @rootPackage
    @resolver = resolver
    @contextStack = []
    @toplevelElements = []
    @helperNames = {}
  end
  
  def const_missing_delegated(delegator, const)
    ConstPathElement.new(const, self)
  end
  
  # in Ruby 1.9.0 and 1.9.1 #instance_eval looks up constants in the calling scope
  # that's why const_missing needs to be prepared in BuilderContext, too 
  class << self
    def currentBuilderContext=(bc)
     @@currentBuilderContext = bc
    end

    def const_missing(name)
      if @@currentBuilderContext
        ConstPathElement.new(name, @@currentBuilderContext)
      else
        super
      end
    end
  end

  class CommandResolver
    def initialize(rootPackage, extensionsModule, builderContext)
      @extensionFactory = ExtensionContainerFactory.new(rootPackage, extensionsModule, builderContext)
      @packageResolver = PackageResolver.new(rootPackage, @extensionFactory)
      @resolveCommand = {}
    end
    
    def resolveCommand(cmd, parentPackage)
      return @resolveCommand[[parentPackage, cmd]] if @resolveCommand.has_key?([parentPackage, cmd])
      package = @packageResolver.packageByCommand(parentPackage, cmd)
      result = nil
	    if package
  	    extensionContainer = @extensionFactory.extensionContainer(package)
  	    if extensionContainer.respond_to?(cmd)
          result = extensionContainer
        else
    	    className = cmd.to_s[0..0].upcase + cmd.to_s[1..-1]
    	    result = package.eClasses.find{|c| c.name == className}
        end
      end
      @resolveCommand[[parentPackage, cmd]] = [package, result]
	  end
  end
  
  def method_missing(m, *args, &block)
    package, classOrContainer = @commandResolver.resolveCommand(m, @package)
    return super if package.nil?
    return classOrContainer.send(m, *args, &block) if classOrContainer.is_a?(ExtensionContainerFactory::ExtensionContainer)
    eClass = classOrContainer
    nameArg, argHash = self.class.processArguments(args)
    internalName = nameArg || argHash[:name]
    argHash[:name] ||= nameArg if nameArg && self.class.hasNameAttribute(eClass)
    resolverJobs, asRole, helperName = self.class.filterArgHash(argHash, eClass)
    element = eClass.instanceClass.new(argHash)
    @resolver.setElementName(element, internalName)
    @env << element if @env
    contextElement = @contextStack.last
    if contextElement
      self.class.associateWithContextElement(element, contextElement, asRole)
    else
      @toplevelElements << element
    end
    resolverJobs.each do |job|
      job.receiver = element
      job.namespace = contextElement
      @resolver.addJob(job)
    end
    # process block
    if block
      @contextStack.push(element)
      @package, oldPackage = package, @package
      instance_eval(&block)
      @package = oldPackage
      @contextStack.pop
    end
    element
  end
  
  def _using(constPathElement, &block)
    @package, oldPackage = 
      self.class.resolvePackage(@package, @rootPackage, constPathElement.constPath), @package
    instance_eval(&block)
    @package = oldPackage
  end
  
  def _context(depth=1)
    @contextStack[-depth]
  end

  class ExtensionContainerFactory
    
    class ExtensionContainer
      def initialize(builderContext)
        @builderContext = builderContext
      end
      def method_missing(m, *args, &block)
        @builderContext.send(m, *args, &block)
      end
    end
    
    def initialize(rootPackage, extensionsModule, builderContext)
      @rootPackage, @extensionsModule, @builderContext = rootPackage, extensionsModule, builderContext
      @extensionContainer = {}
    end
    
    def moduleForPackage(package)
      qName = package.qualifiedName
      rqName = @rootPackage.qualifiedName
      raise "Package #{qName} is not contained within #{rqName}" unless qName.index(rqName) == 0
      path = qName.sub(rqName,'').split('::')
      path.shift if path.first == ""
      mod = @extensionsModule
      path.each do |p|
        if mod && mod.const_defined?(p)
          mod = mod.const_get(p)
        else
          mod = nil
          break
        end
      end
      mod
    end
    
    def extensionContainer(package)
      return @extensionContainer[package] if @extensionContainer[package]
      container = ExtensionContainer.new(@builderContext)
      extensionModule = moduleForPackage(package)
      container.extend(extensionModule) if extensionModule
      @extensionContainer[package] = container
    end
  end
  
  class PackageResolver
    def initialize(rootPackage, extensionFactory)
      @rootPackage = rootPackage
      @extensionFactory = extensionFactory
      @packageByCommand = {}
    end
    
    def packageByCommand(contextPackage, name)
      return @packageByCommand[[contextPackage, name]] if @packageByCommand.has_key?([contextPackage, name])
      if @extensionFactory.extensionContainer(contextPackage).respond_to?(name)
        result = contextPackage
      else
        className = name.to_s[0..0].upcase + name.to_s[1..-1]
        eClass = contextPackage.eClasses.find{|c| c.name == className}
        if eClass
          result = contextPackage
        elsif contextPackage != @rootPackage
          result = packageByCommand(contextPackage.eSuperPackage, name)
        else
          result = nil
        end
      end
      @packageByCommand[[contextPackage, name]] = result
    end
  end
  
  class ConstPathElement < Module
    def initialize(name, builderContext, parent=nil)
      @name = name.to_s
      @builderContext = builderContext
      @parent = parent
    end
    
    def const_missing(const)
      ConstPathElement.new(const, @builderContext, self)
    end
    
    def method_missing(m, *args, &block)
      @builderContext._using(self) do
        send(m, *args, &block)
      end
    end
    
    def constPath
      if @parent
        @parent.constPath << @name
      else
        [@name]
      end
    end
  end

  # helper methods put in the class object to be out of the way of 
  # method evaluation in the builder context
  class << self
    class PackageNotFoundException < Exception
    end
  
    def resolvePackage(contextPackage, rootPackage, path)
      begin
        return resolvePackageDownwards(contextPackage, path)
      rescue PackageNotFoundException
        if contextPackage.eSuperPackage && contextPackage != rootPackage
          return resolvePackage(contextPackage.eSuperPackage, rootPackage, path)
        else
          raise
        end
      end
    end
  
    def resolvePackageDownwards(contextPackage, path)
      first, *rest = path
      package = contextPackage.eSubpackages.find{|p| p.name == first}
      raise PackageNotFoundException.new("Could not resolve package: #{first} is not a subpackage of #{contextPackage.name}") unless package
      if rest.empty?
        package 
      else
        resolvePackageDownwards(package, rest)
      end
    end
    
    def processArguments(args)
      unless (args.size == 2 && args.first.is_a?(String) && args.last.is_a?(Hash)) ||
        (args.size == 1 && (args.first.is_a?(String) || args.first.is_a?(Hash))) ||
        args.size == 0
        raise "Provide a Hash to set feature values, " +
          "optionally the first argument may be a String specifying " + 
          "the value of the \"name\" attribute."
      end
      if args.last.is_a?(Hash)
        argHash = args.last
      else
        argHash = {}
      end
      nameArg = args.first if args.first.is_a?(String)
      [nameArg, argHash]
    end
    
    def filterArgHash(argHash, eClass)
      resolverJobs = []
      asRole, helperName = nil, nil
      refByName = {}
      eAllReferences(eClass).each {|r| refByName[r.name] = r}
      argHash.each_pair do |k,v|
        if k == :as
          asRole = v
          argHash.delete(k)
        elsif k == :name && !hasNameAttribute(eClass)
          helperName = v          
          argHash.delete(k)
        elsif v.is_a?(String)
          ref = refByName[k.to_s]#eAllReferences(eClass).find{|r| r.name == k.to_s}
          if ref
            argHash.delete(k)
            resolverJobs << ReferenceResolver::ResolverJob.new(nil, ref, nil,  v)
          end
        elsif v.is_a?(Array)
          ref = refByName[k.to_s] #eAllReferences(eClass).find{|r| r.name == k.to_s}
          ref && v.dup.each do |e|
            if e.is_a?(String)
              v.delete(e)
              resolverJobs << ReferenceResolver::ResolverJob.new(nil, ref, nil, e)
            end
          end
        end
      end
      [ resolverJobs, asRole, helperName ]
    end
    
    def hasNameAttribute(eClass)
      @hasNameAttribute ||= {}
      @hasNameAttribute[eClass] ||= eClass.eAllAttributes.any?{|a| a.name == "name"}
    end
  
    def eAllReferences(eClass)
      @eAllReferences ||= {}
      @eAllReferences[eClass] ||= eClass.eAllReferences
    end
    
    def containmentRefs(contextClass, eClass)
      @containmentRefs ||= {}
      @containmentRefs[[contextClass, eClass]] ||=
        eAllReferences(contextClass).select do |r| 
          r.containment && (eClass.eAllSuperTypes << eClass).include?(r.eType)
        end
    end
  
    def associateWithContextElement(element, contextElement, asRole)
      return unless contextElement
      contextClass = contextElement.class.ecore
      if asRole
        asRoleRef = eAllReferences(contextClass).find{|r| r.name == asRole.to_s}
        raise "Context class #{contextClass.name} has no reference named #{asRole}" unless asRoleRef
        ref = asRoleRef
      else
        possibleContainmentRefs = containmentRefs(contextClass, element.class.ecore)
        if possibleContainmentRefs.size == 1
          ref = possibleContainmentRefs.first
        elsif possibleContainmentRefs.size == 0
          raise "Context class #{contextClass.name} can not contain a #{element.class.ecore.name}"
        else
          raise "Context class #{contextClass.name} has several containment references to a #{element.class.ecore.name}." +
            " Clearify using \":as => <role>\""
        end
      end
      if ref.many
        contextElement.addGeneric(ref.name, element)
      else
        contextElement.setGeneric(ref.name, element)
      end
    end
    
  end
  
end

end
  
end
