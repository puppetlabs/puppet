module RGen

module MetamodelBuilder

module DataTypes

  # An enum object is used to describe possible attribute values within a 
  # MetamodelBuilder attribute definition. An attribute defined this way can only
  # take the values specified when creating the Enum object. 
  # Literal values can only be symbols or true or false.
  # Optionally a name may be specified for the enum object.
  # 
  # Examples:
  # 
  # 	Enum.new(:name => "AnimalEnum", :literals => [:cat, :dog])
  # 	Enum.new(:literals => [:cat, :dog])
  # 	Enum.new([:cat, :dog])
  # 
	class Enum
	  attr_reader :name, :literals
	  
	  # Creates a new named enum type object consisting of the elements passed as arguments.
	  def initialize(params)
      MetamodelBuilder::ConstantOrderHelper.enumCreated(self)
	  	if params.is_a?(Array)
		    @literals = params
	  		@name = "anonymous"
	  	elsif params.is_a?(Hash)
	  		raise StandardError.new("Hash entry :literals is missing") unless params[:literals]
	  		@literals = params[:literals]
	  		@name = params[:name] || "anonymous"
	  	else
	  		raise StandardError.new("Pass an Array or a Hash")
	  	end
	  end

		# This method can be used to check if an object can be used as value for
		# variables having this enum object as type.	  
	  def validLiteral?(l)
	    literals.include?(l)
	  end
	  
	  def literals_as_strings
	  	literals.collect do |l|
	  		if l.is_a?(Symbol)
          if l.to_s =~ /^\d|\W/
            ":'"+l.to_s+"'"
          else
            ":"+l.to_s
          end
	  		elsif l.is_a?(TrueClass) || l.is_a?(FalseClass)
	  			l.to_s
	  		else
	  			raise StandardError.new("Literal values can only be symbols or true/false")
	  		end
	  	end
	  end
	  
	  def to_s # :nodoc:
	  	name
	  end
	end
	
	# Boolean is a predefined enum object having Ruby's true and false singletons
	# as possible values.
	Boolean = Enum.new(:name => "Boolean", :literals => [true, false])

	# Long represents a 64-bit Integer
  # This constant is merely a marker for keeping this information in the Ruby version of the metamodel,
  # values of this type will always be instances of Integer or Bignum;
  # Setting it to a string value ensures that it responds to "to_s" which is used in the metamodel generator
	Long = "Long"
end

end

end
