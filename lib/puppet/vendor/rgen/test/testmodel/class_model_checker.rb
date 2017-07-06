require 'metamodels/uml13_metamodel'
require 'metamodels/uml13_metamodel_ext'

module Testmodel

# Checks the UML Class model elements from the example model
# 
module ClassModelChecker			
    
	def checkClassModel(envUML)
						
		# check main package
		mainPackage = envUML.find(:class => UML13::Package, :name => "HouseMetamodel").first
		assert_not_nil mainPackage
		
		# check Rooms package
		subs = mainPackage.ownedElement.select{|e| e.is_a?(UML13::Package)}
		assert_equal 1, subs.size
		roomsPackage = subs.first
		assert_equal "Rooms", roomsPackage.name
		
		# check main package classes
		classes = mainPackage.ownedElement.select{|e| e.is_a?(UML13::Class)}
		assert_equal 3, classes.size
		houseClass = classes.find{|c| c.name == "House"}
		personClass = classes.find{|c| c.name == "Person"}
		meetingPlaceClass = classes.find{|c| c.name == "MeetingPlace"}
		cookingPlaceInterface = mainPackage.ownedElement.find{|e| e.is_a?(UML13::Interface) && e.name == "CookingPlace"}
		assert_not_nil houseClass
		assert_not_nil personClass
		assert_not_nil meetingPlaceClass
        assert_not_nil cookingPlaceInterface

		# check Rooms package classes
		classes = roomsPackage.ownedElement.select{|e| e.is_a?(UML13::Class)}
		assert_equal 3, classes.size
		roomClass = classes.find{|c| c.name == "Room"}
		kitchenClass = classes.find{|c| c.name == "Kitchen"}
		bathroomClass = classes.find{|c| c.name == "Bathroom"}
		assert_not_nil roomClass
		assert_not_nil kitchenClass
		assert_not_nil bathroomClass
		
		# check Room inheritance
		assert_equal 2, roomClass.specialization.child.size
		assert_not_nil roomClass.specialization.child.find{|c| c.name == "Kitchen"}
		assert_not_nil roomClass.specialization.child.find{|c| c.name == "Bathroom"}
		assert_equal 2, kitchenClass.generalization.parent.size
		assert_equal roomClass.object_id, kitchenClass.generalization.parent.find{|c| c.name == "Room"}.object_id
		assert_equal meetingPlaceClass.object_id, kitchenClass.generalization.parent.find{|c| c.name == "MeetingPlace"}.object_id
		assert_equal 1, bathroomClass.generalization.parent.size
		assert_equal roomClass.object_id, bathroomClass.generalization.parent.first.object_id
		assert_not_nil kitchenClass.clientDependency.find{|d| d.stereotype.name == "implements"}
        assert_equal cookingPlaceInterface.object_id, kitchenClass.clientDependency.supplier.find{|c| c.name == "CookingPlace"}.object_id
        assert_equal kitchenClass.object_id, cookingPlaceInterface.supplierDependency.client.find{|c| c.name == "Kitchen"}.object_id

		# check House-Room "part of" association
		assert_equal 1, houseClass.localCompositeEnd.size
		roomEnd = houseClass.localCompositeEnd.first.otherEnd
		assert_equal UML13::Association, roomEnd.association.class
		assert_equal roomClass.object_id, roomEnd.type.object_id
		assert_equal "room", roomEnd.name
		assert_equal UML13::Multiplicity, roomEnd.multiplicity.class
		assert_equal "1", roomEnd.multiplicity.range.first.lower
		assert_equal "*", roomEnd.multiplicity.range.first.upper
		
		assert_equal 1, roomClass.remoteCompositeEnd.size
		assert_equal houseClass.object_id, roomClass.remoteCompositeEnd.first.type.object_id
		assert_equal "house", roomClass.remoteCompositeEnd.first.name
				
		# check House OUT associations
		assert_equal 2, houseClass.remoteNavigableEnd.size
		bathEnd = houseClass.remoteNavigableEnd.find{|e| e.name == "bathroom"}
		kitchenEnd = houseClass.remoteNavigableEnd.find{|e| e.name== "kitchen"}
		assert_not_nil bathEnd
		assert_not_nil kitchenEnd
		assert_equal UML13::Association, bathEnd.association.class
		assert_equal UML13::Association, kitchenEnd.association.class
		assert_equal "1", kitchenEnd.multiplicity.range.first.lower
		assert_equal "1", kitchenEnd.multiplicity.range.first.upper
		
		# check House IN associations
		assert_equal 3, houseClass.localNavigableEnd.size
		homeEnd = houseClass.localNavigableEnd.find{|e| e.name == "home"}
		assert_not_nil homeEnd
		assert_equal UML13::Association, homeEnd.association.class
		assert_equal "0", homeEnd.multiplicity.range.first.lower
		assert_equal "*", homeEnd.multiplicity.range.first.upper
		
		# check House all associations
		assert_equal 4, houseClass.associationEnd.size
	end

    def checkClassModelPartial(envUML)
        # HouseMetamodel package is not part of the partial export
		mainPackage = envUML.find(:class => UML13::Package, :name => "HouseMetamodel").first
		assert_nil mainPackage
		
		roomsPackage = envUML.find(:class => UML13::Package, :name => "Rooms").first
		assert_not_nil roomsPackage
		
		roomClass = envUML.find(:class => UML13::Class, :name => "Room").first
		assert_not_nil roomClass
		
		# House is created from an EAStub
		houseClass = roomClass.remoteCompositeEnd.first.type
		assert_not_nil houseClass
		assert_equal "House", houseClass.name
        # House is not in a package since it's just a stub
		assert houseClass.namespace.nil?
		
		# in the partial model, House has only 3 (not 4) associations
		# since the fourth class (Person) is not in Rooms package
		assert_equal 3, houseClass.associationEnd.size
    end
    
end

end