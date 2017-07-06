module RGen

module Util

module ModelDumper

	def dump(obj=nil)
		obj ||= self
		if obj.is_a?(Array)
			obj.collect {|o| dump(o)}.join("\n\n")
		elsif obj.class.respond_to?(:ecore)
			([obj.to_s] +
			obj.class.ecore.eAllStructuralFeatures.select{|f| !f.many}.collect { |a| 
				"   #{a} => #{obj.getGeneric(a.name)}"
			} +
			obj.class.ecore.eAllStructuralFeatures.select{|f| f.many}.collect { |a|
				"   #{a} => [ #{obj.getGeneric(a.name).join(', ')} ]"
			}).join("\n")
		else
			obj.to_s
		end
	end

end

end

end

