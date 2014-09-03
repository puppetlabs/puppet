require 'rgen/metamodel_builder'

module HouseMetamodel
   extend RGen::MetamodelBuilder::ModuleExtension
   include RGen::MetamodelBuilder::DataTypes

   SexEnum = Enum.new(:name => 'SexEnum', :literals =>[ :male, :female ])

   class House < RGen::MetamodelBuilder::MMBase
      annotation :source => "bla", :details => {'a' => 'b'}
      has_attr 'address', String, :changeable => false 
   end

   class MeetingPlace < RGen::MetamodelBuilder::MMBase
   end

   class Person < RGen::MetamodelBuilder::MMBase
      has_attr 'sex', HouseMetamodel::SexEnum 
      has_attr 'id', Long 
      has_many_attr 'nicknames', String 
   end


   module Rooms
      extend RGen::MetamodelBuilder::ModuleExtension
      include RGen::MetamodelBuilder::DataTypes


      class Room < RGen::MetamodelBuilder::MMBase
      end

      class Bathroom < Room
      end

      class Kitchen < RGen::MetamodelBuilder::MMMultiple(Room, HouseMetamodel::MeetingPlace)
      end

   end
end

HouseMetamodel::House.has_one 'bathroom', HouseMetamodel::Rooms::Bathroom, :lowerBound => 1 
HouseMetamodel::House.one_to_one 'kitchen', HouseMetamodel::Rooms::Kitchen, 'house', :lowerBound => 1 
HouseMetamodel::House.contains_many 'room', HouseMetamodel::Rooms::Room, 'house' 
HouseMetamodel::Person.has_many 'house', HouseMetamodel::House 
