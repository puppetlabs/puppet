# RGen Framework
# (c) Martin Thiede, 2006

require 'rgen/metamodel_builder/constant_order_helper'
require 'rgen/metamodel_builder/builder_runtime'
require 'rgen/metamodel_builder/builder_extensions'
require 'rgen/metamodel_builder/module_extension'
require 'rgen/metamodel_builder/data_types'
require 'rgen/metamodel_builder/mm_multiple'
require 'rgen/ecore/ecore_interface'

module RGen

# MetamodelBuilder can be used to create a metamodel, i.e. Ruby classes which
# act as metamodel elements.
# 
# To create a new metamodel element, create a Ruby class which inherits from
# MetamodelBuilder::MMBase
# 
# 	class Person < RGen::MetamodelBuilder::MMBase
# 	end
# 
# This way a couple of class methods are made available to the new class.
# These methods can be used to:
# * add attributes to the class
# * add associations with other classes
# 
# Here is an example:
# 
# 	class Person < RGen::MetamodelBuilder::MMBase
# 		has_attr 'name', String
# 		has_attr 'age', Integer
# 	end
# 
# 	class House < RGen::MetamodelBuilder::MMBase
# 		has_attr 'address' # String is default
# 	end
# 
# 	Person.many_to_many 'homes', House, 'inhabitants'
# 
# See BuilderExtensions for details about the available class methods.
# 
# =Attributes
# 
# The example above creates two classes 'Person' and 'House'. Person has the attributes
# 'name' and 'age', House has the attribute 'address'. The attributes can be 
# accessed on instances of the classes in the following way:
# 
# 	p = Person.new
# 	p.name = "MyName"
# 	p.age = 22
# 	p.name	# => "MyName"
# 	p.age 	# => 22
# 
# Note that the class Person takes care of the type of its attributes. As 
# declared above, a 'name' can only be a String, an 'age' must be an Integer.
# So the following would return an exception:
# 
# 	p.name = :myName	# => exception: can not put a Symbol where a String is expected
# 
# If the type of an attribute should be left undefined, use Object as type.
#
# =Associations
# 
# As well as attributes show up as instance methods, associations bring their own
# accessor methods. For the Person-to-House association this would be:
# 
# 	h1 = House.new
# 	h1.address = "Street1"
# 	h2 = House.new
# 	h2.address = "Street2"
# 	p.addHomes(h1)
# 	p.addHomes(h2)
# 	p.removeHomes(h1)
# 	p.homes	# => [ h2 ]
# 
# The Person-to-House association is _bidirectional_. This means that with the 
# addition of a House to a Person, the Person is also added to the House. Thus:
# 
# 	h1.inhabitants	# => []
# 	h2.inhabitants	# => [ p ]
# 	
# Note that the association is defined between two specific classes, instances of
# different classes can not be added. Thus, the following would result in an 
# exception:
# 
# 	p.addHomes(:justASymbol) # => exception: can not put a Symbol where a House is expected
#
# =ECore Metamodel description
# 
# The class methods described above are used to create a Ruby representation of the metamodel
# we have in mind in a very simple and easy way. We don't have to care about all the details
# of a metamodel at this point (e.g. multiplicities, changeability, etc).
# 
# At the same time however, an instance of the ECore metametamodel (i.e. a ECore based
# description of our metamodel) is provided for all the Ruby classes and modules we create.
# Since we did not provide the nitty-gritty details of the metamodel, defaults are used to
# fully complete the ECore metamodel description.
#
# In order to access the ECore metamodel description, just call the +ecore+ method on a
# Ruby class or module object belonging to your metamodel.
# 
# Here is the example continued from above:
# 
# 	Person.ecore.eAttributes.name # => ["name", "age"]
# 	h2pRef = House.ecore.eReferences.first
# 	h2pRef.eType                  # => Person
# 	h2pRef.eOpposite.eType        # => House
# 	h2pRef.lowerBound             # => 0
# 	h2pRef.upperBound             # => -1
# 	h2pRef.many                   # => true
# 	h2pRef.containment            # => false
# 
# Note that the use of array_extensions.rb is assumed here to make model navigation convenient.
# 
# The following metamodel builder methods are supported, see individual method description
# for details:
# 
# Attributes:
# * BuilderExtensions#has_attr
# 
# Unidirectional references:
# * BuilderExtensions#has_one
# * BuilderExtensions#has_many
# * BuilderExtensions#contains_one_uni
# * BuilderExtensions#contains_many_uni
# 
# Bidirectional references:
# * BuilderExtensions#one_to_one
# * BuilderExtensions#one_to_many
# * BuilderExtensions#many_to_one
# * BuilderExtensions#many_to_many
# * BuilderExtensions#contains_one
# * BuilderExtensions#contains_many
# 
# Every builder command can optionally take a specification of further ECore properties.
# Additional properties for Attributes and References are (with defaults in brackets):
# * :ordered (true), 
# * :unique (true),
# * :changeable (true),
# * :volatile (false),
# * :transient (false),
# * :unsettable (false),
# * :derived (false),
# * :lowerBound (0),
# * :resolveProxies (true) <i>references only</i>,
# 
# Using these additional properties, the above example can be refined as follows:
# 
# 	class Person < RGen::MetamodelBuilder::MMBase
# 		has_attr 'name', String, :lowerBound => 1
# 		has_attr 'yearOfBirth', Integer,
# 		has_attr 'age', Integer, :derived => true
# 		def age_derived
# 			Time.now.year - yearOfBirth
# 		end
# 	end
# 
# 	Person.many_to_many 'homes', House, 'inhabitants', :upperBound => 5
# 
# 	Person.ecore.eReferences.find{|r| r.name == 'homes'}.upperBound # => 5
# 
# This way we state that there must be a name for each person, we introduce a new attribute
# 'yearOfBirth' and make 'age' a derived attribute. We also say that a person can 
# have at most 5 houses in our metamodel.
# 
# ==Derived attributes and references
# 
# If the attribute 'derived' of an attribute or reference is set to true, a method +attributeName_derived+
# has to be provided. This method is called whenever the original attribute is accessed. The
# original attribute can not be written if it is derived.
# 
#
module MetamodelBuilder	

	# Use this class as a start for new metamodel elements (i.e. Ruby classes)
	# by inheriting for it.
	# 
	# See MetamodelBuilder for an example.
	class MMBase
		include BuilderRuntime
		include DataTypes
		extend BuilderExtensions
		extend ModuleExtension
		extend RGen::ECore::ECoreInterface
		
		def initialize(arg=nil)
			raise StandardError.new("Class #{self.class} is abstract") if self.class._abstract_class 
	    arg.each_pair { |k,v| setGeneric(k, v) } if arg.is_a?(Hash)
		end

    # Object#inspect causes problems on most models 
    def inspect
      self.class.name
    end
    
	  def self.method_added(m)
	    raise "Do not add methods to model classes directly, add them to the ClassModule instead"
	  end
	end
	
  # Instances of MMGeneric can be used as values of any attribute are reference
  class MMGeneric
    # empty implementation so we don't have to check if a value is a MMGeneriv before setting the container
    def _set_container(container, containing_feature_name)
    end
  end

  # MMProxy objects can be used instead of real target elements in case references should be resolved later on
  class MMProxy < MMGeneric
    # The +targetIdentifer+ is an object identifying the element the proxy represents
    attr_accessor :targetIdentifier
    # +data+ is optional additional information to be associated with the proxy
    attr_accessor :data

    def initialize(ident=nil, data=nil)
      @targetIdentifier = ident
      @data = data
    end
  end

end

end
