require 'metamodels/uml13_metamodel'
require 'metamodels/uml13_metamodel_ext'

module Testmodel

# Checks the UML Object model elements from the example model
# 
module ObjectModelChecker

    # convenient extension for this test only
    module UML13::ClassifierRole::ClassModule
      def classname
        taggedValue.find{|tv| tv.tag == "classname"}.value
      end
    end
    
	def checkObjectModel(envUML)
		
		# check main package
		mainPackage = envUML.find(:class => UML13::Package, :name => "HouseExampleModel").first
		assert_not_nil mainPackage
		
		eaRootCollaboration = mainPackage.ownedElement.find{|e| e.is_a?(UML13::Collaboration) && e.name == "Collaborations"}
        assert_not_nil eaRootCollaboration

		# check main package objects
        objects = eaRootCollaboration.ownedElement.select{|e| e.is_a?(UML13::ClassifierRole)}
		assert_equal 6, objects.size

		someone = objects.find{|o| o.name == "Someone"}
		assert_equal "Person", someone.classname
		
		someonesHouse = objects.find{|o| o.name == "SomeonesHouse"}
		assert_equal "House", someonesHouse.classname

		greenRoom = objects.find{|o| o.name == "GreenRoom"}
		assert_equal "Room", greenRoom.classname

		yellowRoom = objects.find{|o| o.name == "YellowRoom"}
		assert_equal "Room", yellowRoom.classname

		hotRoom = objects.find{|o| o.name == "HotRoom"}
		assert_equal "Kitchen", hotRoom.classname

		wetRoom = objects.find{|o| o.name == "WetRoom"}
		assert_equal "Bathroom", wetRoom.classname
		
		# Someone to SomeonesHouse
		assert someone.associationEnd.otherEnd.getType.is_a?(Array)
		assert_equal 1, someone.associationEnd.otherEnd.getType.size
		houseEnd = someone.associationEnd.otherEnd[0]
		assert_equal someonesHouse.object_id, houseEnd.getType.object_id
		assert_equal "home", houseEnd.name
		
		# Someone to SomeonesHouse
		assert someonesHouse.localCompositeEnd.otherEnd.is_a?(Array)
		assert_equal 4, someonesHouse.localCompositeEnd.otherEnd.size
		assert someonesHouse.localCompositeEnd.otherEnd.all?{|e| e.name == "room"}
		assert_not_nil someonesHouse.localCompositeEnd.otherEnd.getType.find{|o| o == yellowRoom}
		assert_not_nil someonesHouse.localCompositeEnd.otherEnd.getType.find{|o| o == greenRoom}
		assert_not_nil someonesHouse.localCompositeEnd.otherEnd.getType.find{|o| o == hotRoom}
		assert_not_nil someonesHouse.localCompositeEnd.otherEnd.getType.find{|o| o == wetRoom}

	end
end

end