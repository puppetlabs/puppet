require 'andand'

module RGen

module Util
	
class ModelComparatorBase
	
	CompareSpec = Struct.new(:identifier, :recurse, :filter, :ignore_features, :display_name, :sort)
	INDENT = "  "	

	class << self
		attr_reader :compareSpecs
		
		def compare_spec(clazz, hash)
			@compareSpecs ||= {}
			raise "Compare spec already defined for #{clazz}" if @compareSpecs[clazz]
			spec = CompareSpec.new
			hash.each_pair do |k,v|
				spec.send("#{k}=",v)
			end
			@compareSpecs[clazz] = spec
		end
	end
	
	# compares two sets of elements
	def compare(as, bs, recursive=true)
		result = []
		aById = as.select{|e| useElement?(e)}.inject({}){|r, e| r[elementIdentifier(e)] = e; r}
		bById = bs.select{|e| useElement?(e)}.inject({}){|r, e| r[elementIdentifier(e)] = e; r}
		onlyA = sortElements((aById.keys - bById.keys).collect{|id| aById[id]})
		onlyB = sortElements((bById.keys - aById.keys).collect{|id| bById[id]})
		aAndB = sortElementPairs((aById.keys & bById.keys).collect{|id| [aById[id], bById[id]]})
		onlyA.each do |e|
			result << "- #{elementDisplayName(e)}"
		end
		onlyB.each do |e|
			result << "+ #{elementDisplayName(e)}"
		end
		if recursive
			aAndB.each do |ab|
				a, b = *ab
				r = compareElements(a, b)
				if r.size > 0
					result << "#{elementDisplayName(a)}"
					result += r.collect{|l| INDENT+l}
				end
			end
		end
		result
	end
	
	def sortElementPairs(pairs)
		pairs.sort do |x,y|
			a, b = x[0], y[0]
			r = a.class.name <=> b.class.name
			r = compareSpec(a).sort.call(a,b) if r == 0 && compareSpec(a) && compareSpec(a).sort
			r
		end
	end
	
	def sortElements(elements)
		elements.sort do |a,b|
			r = a.class.name <=> b.class.name
			r = compareSpec(a).sort.call(a,b) if r == 0 && compareSpec(a) && compareSpec(a).sort
			r
		end
	end
	
	def elementDisplayName(e)
		if compareSpec(e) && compareSpec(e).display_name
			compareSpec(e).display_name.call(e)
		else
			elementIdentifier(e)
		end
	end
	
	def compareElements(a, b)
		result = []
		if a.class != b.class
			result << "Class: #{a.class} -> #{b.class}"
		else
			a.class.ecore.eAllStructuralFeatures.reject{|f| f.derived || compareSpec(a).andand.ignore_features.andand.include?(f.name.to_sym)}.each do |f|
				va, vb = a.getGeneric(f.name), b.getGeneric(f.name)
				if f.is_a?(RGen::ECore::EAttribute)
					r = compareValues(f.name, va, vb)
					result << r if r
				else
					va, vb = [va].compact, [vb].compact unless f.many
					r = compare(va, vb, f.containment || compareSpec(a).andand.recurse.andand.include?(f.name.to_sym))
					if r.size > 0
						result << "[#{f.name}]"
						result += r.collect{|l| INDENT+l}
					end
				end	
			end
		end
		result
	end
	
	def compareValues(name, val1, val2)
		result = nil
		result = "[#{name}] #{val1} -> #{val2}" if val1 != val2
		result
	end
	
	def elementIdentifier(element)
		cs = compareSpec(element)
		if cs && cs.identifier
			if cs.identifier.is_a?(Proc)
				cs.identifier.call(element)
			else
				cs.identifier
			end
		else
			if element.respond_to?(:name)
				element.name
			else
				element.object_id
			end
		end
	end
	
	def useElement?(element)
		cs = compareSpec(element)
		!(cs && cs.filter) || cs.filter.call(element)
	end
	
	def compareSpec(element)
		@compareSpec ||= {}
		return @compareSpec[element.class] if @compareSpec[element.class]
		return nil unless self.class.compareSpecs
		key = self.class.compareSpecs.keys.find{|k| element.is_a?(k)}
		@compareSpec[element.class] = self.class.compareSpecs[key]
	end
	
end

end

end

