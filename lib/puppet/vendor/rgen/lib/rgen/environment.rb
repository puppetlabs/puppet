module RGen

# An Environment is used to hold model elements.
#
class Environment

	def initialize
		@elements = {}
		@subClasses = {}
		@subClassesUpdated = {}
    @deleted = {}
    @deletedClasses = {}
	end
	
	# Add a model element. Returns the environment so <code><<</code> can be chained.
	# 
	def <<(el)
		clazz = el.class
		@elements[clazz] ||= []
		@elements[clazz] << el
		updateSubClasses(clazz)
		self
	end

	# Removes model element from environment.
	def delete(el)
    @deleted[el] = true
    @deletedClasses[el.class] = true
	end
		
	# Iterates each element
	#
	def each(&b)
    removeDeleted
		@elements.values.flatten.each(&b)
	end
	
	# Return the elements of the environment as an array
	#
	def elements
    removeDeleted
		@elements.values.flatten
	end
	
	# This method can be used to instantiate a class and automatically put it into
	# the environment. The new instance is returned.
	#
	def new(clazz, *args)
		obj = clazz.new(*args)
		self << obj
		obj
	end
	
	# Finds and returns model elements in the environment.
	# 
	# The search description argument must be a hash specifying attribute/value pairs.
	# Only model elements are returned which respond to the specified attribute methods
	# and return the specified values as result of these attribute methods.
	# 
	# As a special hash key :class can be used to look for model elements of a specific
	# class. In this case an array of possible classes can optionally be given.
	# 
	def find(desc)
    removeDeleted
		result = []
		classes = desc[:class] if desc[:class] and desc[:class].is_a?(Array)
		classes = [ desc[:class] ] if !classes and desc[:class]
		if classes
			hashKeys = classesWithSubClasses(classes)
		else
			hashKeys = @elements.keys
		end
		hashKeys.each do |clazz|
			next unless @elements[clazz]
			@elements[clazz].each do |e|
				failed = false
				desc.each_pair { |k,v|
					failed = true if k != :class and ( !e.respond_to?(k) or e.send(k) != v )
				}
				result << e unless failed
			end
		end
		result
	end
	
	private

  def removeDeleted
    @deletedClasses.keys.each do |c|
      @elements[c].reject!{|e| @deleted[e]}
    end
    @deletedClasses.clear
    @deleted.clear
  end
	
	def updateSubClasses(clazz)
		return if @subClassesUpdated[clazz]
		if clazz.respond_to?( :ecore )
			superClasses = clazz.ecore.eAllSuperTypes.collect{|c| c.instanceClass}
		else
			superClasses = superclasses(clazz)
		end
		superClasses.each do |c|
			next if c == Object
			@subClasses[c] ||= []
			@subClasses[c] << clazz
		end
		@subClassesUpdated[clazz] = true
	end	
	
	def classesWithSubClasses(classes)
		result = classes
		classes.each do |c|
			result += @subClasses[c] if @subClasses[c]
		end
		result.uniq
	end
	
	def superclasses(clazz)
		if clazz == Object
			[]
		else
			superclasses(clazz.superclass) << clazz.superclass
		end
	end
	
end

end