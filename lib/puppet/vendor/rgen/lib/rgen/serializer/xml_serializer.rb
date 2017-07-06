module RGen

module Serializer

class XMLSerializer

  INDENT_SPACE = 2
  
	def initialize(file)
    @indent = 0
    @lastStartTag = nil
    @textContent = false
    @file = file
	end
	
	def serialize(rootElement)
		raise "Abstract class, overwrite method in subclass!"
	end
  
  def startTag(tag, attributes={})
    @textContent = false
    handleLastStartTag(false, true)
    if attributes.is_a?(Hash)
      attrString = attributes.keys.collect{|k| "#{k}=\"#{attributes[k]}\""}.join(" ")
    else
      attrString = attributes.collect{|pair| "#{pair[0]}=\"#{pair[1]}\""}.join(" ")
    end
    @lastStartTag = " "*@indent*INDENT_SPACE + "<#{tag} "+attrString
    @indent += 1
  end
  
  def endTag(tag)
    @indent -= 1
    unless handleLastStartTag(true, true)
      output " "*@indent*INDENT_SPACE unless @textContent
      output "</#{tag}>\n"
    end
    @textContent = false
  end

  def writeText(text)
    handleLastStartTag(false, false)
    output "#{text}"
    @textContent = true
  end  
	
	protected

  def eAllReferences(element)
    @eAllReferences ||= {}
    @eAllReferences[element.class] ||= element.class.ecore.eAllReferences
  end

  def eAllAttributes(element)
    @eAllAttributes ||= {}
    @eAllAttributes[element.class] ||= element.class.ecore.eAllAttributes
  end
    
  def eAllStructuralFeatures(element)
    @eAllStructuralFeatures ||= {}
    @eAllStructuralFeatures[element.class] ||= element.class.ecore.eAllStructuralFeatures
  end

	def eachReferencedElement(element, refs, &block)
		refs.each do |r|
			targetElements = element.getGeneric(r.name)
			targetElements = [targetElements] unless targetElements.is_a?(Array)
			targetElements.each do |te|
				yield(r,te)
			end
		end			
	end  

  def containmentReferences(element)
    @containmentReferences ||= {}
    @containmentReferences[element.class] ||= eAllReferences(element).select{|r| r.containment}
  end
  
  private
  
  def handleLastStartTag(close, newline)
    return false unless @lastStartTag
    output @lastStartTag
    output close ? "/>" : ">"
    output "\n" if newline
    @lastStartTag = nil
    true
  end
  
  def output(text)
    @file.write(text)
  end
  
end

end

end
