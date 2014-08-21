require 'rgen/metamodel_builder'

module HouseMetamodel
  extend RGen::MetamodelBuilder::ModuleExtension
  include RGen::MetamodelBuilder::DataTypes
  
  SexEnum = Enum.new(:name => "SexEnum", :literals => [ :male, :female ])
  # TODO: Datatypes
  #   AggregationKind = Enum.new([ :none, :aggregate, :composite ])
  
  class MeetingPlace < RGen::MetamodelBuilder::MMBase
    annotation :source => "testmodel", :details => { 'complexity' => '1', 'date_created' => '2006-07-12 08:40:46', 'date_modified' => '2006-07-12 08:44:02', 'ea_ntype' => '0', 'ea_stype' => 'Class', 'gentype' => 'Java', 'isSpecification' => 'false', 'package' => 'EAPK_A1B83D59_CAE1_422c_BA5F_D3624D7156AD', 'package_name' => 'HouseMetamodel', 'phase' => '1.0', 'status' => 'Proposed', 'style' => 'BackColor=-1;BorderColor=-1;BorderWidth=-1;FontColor=-1;VSwimLanes=0;HSwimLanes=0;BorderStyle=0;', 'tagged' => '0', 'version' => '1.0' }
  end
  
  class Person < RGen::MetamodelBuilder::MMBase
    annotation       'complexity' => '1', 'date_created' => '2006-06-27 08:34:23', 'date_modified' => '2006-06-27 08:34:26', 'ea_ntype' => '0', 'ea_stype' => 'Class', 'gentype' => 'Java', 'isSpecification' => 'false', 'package' => 'EAPK_A1B83D59_CAE1_422c_BA5F_D3624D7156AD', 'package_name' => 'HouseMetamodel', 'phase' => '1.0', 'status' => 'Proposed', 'style' => 'BackColor=-1;BorderColor=-1;BorderWidth=-1;FontColor=-1;VSwimLanes=0;HSwimLanes=0;BorderStyle=0;', 'tagged' => '0', 'version' => '1.0'
  	has_attr 'sex', SexEnum
    has_attr 'id', Long
    has_many_attr 'nicknames', String
  end
  
  class House < RGen::MetamodelBuilder::MMBase
    annotation       'complexity' => '1', 'date_created' => '2005-09-16 19:52:18', 'date_modified' => '2006-02-28 08:29:19', 'ea_ntype' => '0', 'ea_stype' => 'Class', 'gentype' => 'Java', 'isSpecification' => 'false', 'package' => 'EAPK_A1B83D59_CAE1_422c_BA5F_D3624D7156AD', 'package_name' => 'HouseMetamodel', 'phase' => '1.0', 'status' => 'Proposed', 'stereotype' => 'dummy', 'style' => 'BackColor=-1;BorderColor=-1;BorderWidth=-1;FontColor=-1;VSwimLanes=0;HSwimLanes=0;BorderStyle=0;', 'tagged' => '0', 'version' => '1.0'
    has_attr 'size', Integer
    has_attr 'module'
    has_attr 'address', String, :changeable => false      do
      annotation          'collection' => 'false', 'containment' => 'Not Specified', 'derived' => '0', 'duplicates' => '0', 'ea_guid' => '{A8DF581B-9AC6-4f75-AB48-8FAEDFC6E068}', 'lowerBound' => '1', 'ordered' => '0', 'position' => '0', 'styleex' => 'volatile=0;', 'type' => 'String', 'upperBound' => '1'
    end
    
  end
  
  
  module Rooms
    extend RGen::MetamodelBuilder::ModuleExtension
    
    
    class Room < RGen::MetamodelBuilder::MMBase
      abstract
      annotation          'complexity' => '1', 'date_created' => '2005-09-16 19:52:28', 'date_modified' => '2006-06-22 21:15:25', 'ea_ntype' => '0', 'ea_stype' => 'Class', 'gentype' => 'Java', 'isSpecification' => 'false', 'package' => 'EAPK_F9D8C6E3_4DAD_4aa2_AD47_D0ABA4E93E08', 'package_name' => 'Rooms', 'phase' => '1.0', 'status' => 'Proposed', 'style' => 'BackColor=-1;BorderColor=-1;BorderWidth=-1;FontColor=-1;VSwimLanes=0;HSwimLanes=0;BorderStyle=0;', 'tagged' => '0', 'version' => '1.0'
    end
    
    class Bathroom < Room
      annotation          'complexity' => '1', 'date_created' => '2006-06-27 08:32:25', 'date_modified' => '2006-06-27 08:34:23', 'ea_ntype' => '0', 'ea_stype' => 'Class', 'gentype' => 'Java', 'isSpecification' => 'false', 'package' => 'EAPK_F9D8C6E3_4DAD_4aa2_AD47_D0ABA4E93E08', 'package_name' => 'Rooms', 'phase' => '1.0', 'status' => 'Proposed', 'style' => 'BackColor=-1;BorderColor=-1;BorderWidth=-1;FontColor=-1;VSwimLanes=0;HSwimLanes=0;BorderStyle=0;', 'tagged' => '0', 'version' => '1.0'
    end
    
    class Kitchen < RGen::MetamodelBuilder::MMMultiple(HouseMetamodel::MeetingPlace, Room)
      annotation          'complexity' => '1', 'date_created' => '2005-11-30 19:26:13', 'date_modified' => '2006-06-22 21:15:34', 'ea_ntype' => '0', 'ea_stype' => 'Class', 'gentype' => 'Java', 'isSpecification' => 'false', 'package' => 'EAPK_F9D8C6E3_4DAD_4aa2_AD47_D0ABA4E93E08', 'package_name' => 'Rooms', 'phase' => '1.0', 'status' => 'Proposed', 'style' => 'BackColor=-1;BorderColor=-1;BorderWidth=-1;FontColor=-1;VSwimLanes=0;HSwimLanes=0;BorderStyle=0;', 'tagged' => '0', 'version' => '1.0'
    end
    
  end
  
  module DependingOnRooms
    extend RGen::MetamodelBuilder::ModuleExtension
    class RoomSub < Rooms::Room
    end
  end
end

HouseMetamodel::Person.has_many 'home', HouseMetamodel::House do
  annotation    'containment' => 'Unspecified'
end
HouseMetamodel::House.has_one 'bathroom', HouseMetamodel::Rooms::Bathroom, :lowerBound => 1, :transient => true
HouseMetamodel::House.one_to_one 'kitchen', HouseMetamodel::Rooms::Kitchen, 'house', :lowerBound => 1, :opposite_lowerBound => 1 do
  annotation    'containment' => 'Unspecified'
  opposite_annotation    'containment' => 'Unspecified'
end
HouseMetamodel::House.contains_many 'room', HouseMetamodel::Rooms::Room, 'house', :lowerBound => 1 do
  # only an opposite annotation
  opposite_annotation    'containment' => 'Unspecified'
end
