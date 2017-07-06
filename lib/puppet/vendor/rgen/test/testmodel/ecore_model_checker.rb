require 'rgen/ecore/ecore'

module Testmodel

# Checks the ECore model elements created by transformation from the
# UML Class model elements from the example model
# 
module ECoreModelChecker			
	include RGen::ECore

	def checkECoreModel(env)
						
		# check main package
		mainPackage = env.elements.select {|e| e.is_a? EPackage and e.name == "HouseMetamodel"}.first
		assert_not_nil mainPackage
		
		# check Rooms package
		assert mainPackage.eSubpackages.is_a?(Array)
		assert_equal 1, mainPackage.eSubpackages.size
		assert mainPackage.eSubpackages[0].is_a?(EPackage)
		roomsPackage = mainPackage.eSubpackages[0]
		assert_equal "Rooms", roomsPackage.name
		
		# check main package classes
		assert mainPackage.eClassifiers.is_a?(Array)
		assert_equal 4, mainPackage.eClassifiers.size
		assert mainPackage.eClassifiers.all?{|c| c.is_a?(EClass)}
		houseClass = mainPackage.eClassifiers.select{|c| c.name == "House"}.first
		personClass = mainPackage.eClassifiers.select{|c| c.name == "Person"}.first
		meetingPlaceClass = mainPackage.eClassifiers.select{|c| c.name == "MeetingPlace"}.first
		cookingPlaceInterface = mainPackage.eClassifiers.select{|c| c.name == "CookingPlace"}.first
		assert_not_nil houseClass
		assert_not_nil personClass
		assert_not_nil meetingPlaceClass
		assert_not_nil cookingPlaceInterface

		# check Rooms package classes
		assert roomsPackage.eClassifiers.is_a?(Array)
		assert_equal 3, roomsPackage.eClassifiers.size
		assert roomsPackage.eClassifiers.all?{|c| c.is_a?(EClass)}
		roomClass = roomsPackage.eClassifiers.select{|c| c.name == "Room"}.first
		kitchenClass = roomsPackage.eClassifiers.select{|c| c.name == "Kitchen"}.first
		bathroomClass = roomsPackage.eClassifiers.select{|c| c.name == "Bathroom"}.first
		assert_not_nil roomClass
		assert_not_nil kitchenClass
		assert_not_nil bathroomClass
		
		# check Room inheritance
		assert kitchenClass.eSuperTypes.is_a?(Array)
		assert_equal 3, kitchenClass.eSuperTypes.size
		assert_equal roomClass.object_id, kitchenClass.eSuperTypes.select{|c| c.name == "Room"}.first.object_id
		assert_equal meetingPlaceClass.object_id, kitchenClass.eSuperTypes.select{|c| c.name == "MeetingPlace"}.first.object_id
		assert_equal cookingPlaceInterface.object_id, kitchenClass.eSuperTypes.select{|c| c.name == "CookingPlace"}.first.object_id
		assert bathroomClass.eSuperTypes.is_a?(Array)
		assert_equal 1, bathroomClass.eSuperTypes.size
		assert_equal roomClass.object_id, bathroomClass.eSuperTypes[0].object_id

		# check House-Room "part of" association
		assert houseClass.eAllContainments.eType.is_a?(Array)
		assert_equal 1, houseClass.eAllContainments.eType.size
		roomRef = houseClass.eAllContainments.first
		assert_equal roomClass.object_id, roomRef.eType.object_id
		assert_equal "room", roomRef.name
		assert_equal 1, roomRef.lowerBound
		assert_equal(-1, roomRef.upperBound)
		assert_not_nil roomRef.eOpposite
		assert_equal houseClass.object_id, roomRef.eOpposite.eType.object_id
		
		partOfRefs = roomClass.eReferences.select{|r| r.eOpposite && r.eOpposite.containment}
		assert_equal 1, partOfRefs.size
		assert_equal houseClass.object_id, partOfRefs.first.eType.object_id
		assert_equal "house", partOfRefs.first.name
		assert_equal roomRef.object_id, partOfRefs.first.eOpposite.object_id
				
		# check House OUT associations
		assert houseClass.eReferences.is_a?(Array)
		assert_equal 3, houseClass.eReferences.size
		bathRef = houseClass.eReferences.find {|e| e.name == "bathroom"}
		kitchenRef = houseClass.eReferences.find {|e| e.name == "kitchen"}
		roomRef = houseClass.eReferences.find {|e| e.name == "room"}
		assert_not_nil bathRef
		assert_nil bathRef.eOpposite
		assert_not_nil kitchenRef
		assert_not_nil roomRef
		assert_equal 1, kitchenRef.lowerBound
		assert_equal 1, kitchenRef.upperBound
		assert_equal 1, roomRef.lowerBound
		assert_equal(-1, roomRef.upperBound)
		
		# check House IN associations
        houseInRefs = env.find(:class => EReference, :eType => houseClass)
		assert_equal 3, houseInRefs.size
		homeEnd = houseInRefs.find{|e| e.name == "home"}
		assert_not_nil homeEnd
		assert_equal 0, homeEnd.lowerBound
		assert_equal(-1, homeEnd.upperBound)
		
	end
end

end