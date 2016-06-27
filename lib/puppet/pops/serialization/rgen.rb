require_relative 'instance_reader'
require_relative 'instance_writer'

module Puppet::Pops
module Serialization

# @api private
module RGen
  class Base
    def features(impl_class)
      impl_class.ecore.eAllStructuralFeatures.reject {|feature| feature.derived }
    end
  end

  # Instance reader for RGen::Ecore objects
  # @api private
  class RGenReader < Base
    include InstanceReader

    def read(impl_class, value_count, deserializer)
      features = features(impl_class)
      raise SerializationError, "Feature count mismatch for #{impl_class}" unless value_count == features.size
      # Deserializer must know about this instance before we read its attributes
      obj = deserializer.remember(impl_class.new)
      features.each { |feature| obj.setGeneric(feature.name, deserializer.read) }
      obj
    end

    INSTANCE = RGenReader.new
  end

  # Instance writer for RGen::Ecore objects
  # @api private
  class RGenWriter < Base
    include InstanceWriter

    def write(type, value, serializer)
      impl_class = value.class
      features = features(impl_class)
      serializer.start_object(type.name, features.size)
      features.each { |feature| serializer.write(value.getGeneric(feature.name)) }
    end

    INSTANCE = RGenWriter.new
  end

  # A generator that produces a {Types::PTypeSetType} instance based on an ruby {Module}
  # that represents an RGen::ECore::EPackage.
  #
  # The generator is not complete. In particular, it does not deal with:
  # - references that extend beyond eCore and the given ePackage
  # - sub packages
  # - methods
  # - annotations
  #
  class TypeGenerator

    ECore = ::RGen::ECore

    def generate_type_set(namespace, package, loader)
      types = {}
      package.constants.each do |c|
        cls = package.const_get(c)
        next unless cls.is_a?(Class) && cls.respond_to?(:ecore)
        e_class = cls.ecore
        types[e_class.name] = generate_type_hash(e_class)
      end
      type_set = Types::PTypeSetType.new(namespace, {
        Pcore::KEY_PCORE_VERSION => Pcore::PCORE_VERSION,
        Types::KEY_VERSION => '0.1.0',
        Types::KEY_TYPES => types
      }, Pcore::RUNTIME_NAME_AUTHORITY).resolve(Types::TypeParser.singleton, loader)

      type_set.types.values.each do |type|
        type.reader = RGenReader::INSTANCE
        type.writer = RGenWriter::INSTANCE
      end
      type_set
    end

    def generate_type_hash(e_class)
      attributes = {}
      e_class.eStructuralFeatures.each do |feature|
        attr = {}
        attributes[feature.name] = attr
        type = feature_type(feature)
        value = feature.defaultValue
        if value.nil?
          if feature.lowerBound == 0
            if feature.upperBound == -1 || feature.upperBound > 1
              attr[Types::KEY_VALUE] = []
            elsif !feature.derived
              type = Types::POptionalType.new(type)
              attr[Types::KEY_VALUE] = nil
            end
          end
        else
          value = value.to_s if value.is_a?(Symbol)
          attr['value'] = value
        end
        attr[Types::KEY_TYPE] = type
        if feature.derived
          attr[Types::KEY_KIND] = Types::PObjectType::ATTRIBUTE_KIND_DERIVED
        elsif feature.unsettable
          attr[Types::KEY_KIND] = Types::PObjectType::ATTRIBUTE_KIND_CONSTANT
        end
      end
      result = { Types::KEY_ATTRIBUTES => attributes }
      supers = e_class.eSuperTypes
      case supers.size
      when 0
      when 1
        result['parent'] = Types::PTypeReferenceType.new(supers[0].name)
      else
        raise SerializationError, "Multiple inheritance is not supported. #{e_class.name} has #{supers.size} super types"
      end
      result
    end

    def feature_type(feature)
      eType = feature.eType
      type = case eType
      when ECore::EInt, ECore::ELong
        Types::PIntegerType::DEFAULT
      when ECore::EFloat
        Types::PFloatType::DEFAULT
      when ECore::EEnum
        Types::PEnumType.new(eType.eLiterals.map { |e| e.name })
      when ECore::EBoolean
        Types::PBooleanType::DEFAULT
      when ECore::EString
        Types::PStringType::DEFAULT
      when ECore::EClass
        Types::PTypeReferenceType.new(eType.name)
      else
        Types::PAnyType::DEFAULT
      end

      case feature.upperBound
      when 1
        type
      when -1
        Types::PArrayType.new(type, Types::PIntegerType.new(feature.lowerBound))
      else
        Types::PArrayType.new(type, Types::PIntegerType.new(feature.lowerBound, feature.upperBound))
      end
    end
  end
end
end
end
