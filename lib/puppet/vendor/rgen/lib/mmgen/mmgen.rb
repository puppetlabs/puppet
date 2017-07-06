$:.unshift File.join(File.dirname(__FILE__),"..")

require 'ea/xmi_ecore_instantiator'
require 'mmgen/metamodel_generator'

include MMGen::MetamodelGenerator

unless ARGV.length >= 2
	puts "Usage: mmgen.rb <xmi_class_model_file> <root package> (<module>)*"
	exit
else
	file_name = ARGV.shift
	root_package_name = ARGV.shift
	modules = ARGV
	out_file = file_name.gsub(/\.\w+$/,'.rb')
	puts out_file
end

env = RGen::Environment.new
File.open(file_name) { |f|
    puts "instantiating ..."
	XMIECoreInstantiator.new.instantiateECoreModel(env, f.read)
}

rootPackage = env.find(:class => RGen::ECore::EPackage, :name => root_package_name).first

puts "generating ..."
generateMetamodel(rootPackage, out_file, modules)
