require 'nokogiri'

class AbstractXMLInstantiator
    
  class Visitor < Nokogiri::XML::SAX::Document
    
    def initialize(inst, gcSuspendCount)
      @instantiator = inst
      @gcSuspendCount = gcSuspendCount
      @namespaces = {}
    end
    
    def start_element_namespace(tag, attributes, prefix, uri, ns)
      controlGC
      ns.each{|n| @namespaces[n[0]] = n[1]}
      attrs = attributes.collect{|a| [a.prefix ? a.prefix+":"+a.localname : a.localname, a.value]}
      @instantiator.start_tag(prefix, tag, @namespaces, Hash[*(attrs.flatten)])
      attrs.each { |pair| @instantiator.set_attribute(pair[0], pair[1]) }
    end
    
    def end_element_namespace(tag, prefix, uri)
      @instantiator.end_tag(prefix, tag)
    end
    
    def characters(str)
      @instantiator.text(str)
    end
    
    def controlGC
      return unless @gcSuspendCount > 0
      @gcCounter ||= 0
      @gcCounter += 1
      if @gcCounter == @gcSuspendCount
        @gcCounter = 0
        GC.enable
        ObjectSpace.garbage_collect
        GC.disable 
      end 
    end
  end

  # Parses str and calls start_tag, end_tag, set_attribute and text methods of a subclass.
  # 
  # If gcSuspendCount is specified, the garbage collector will be disabled for that
  # number of start or end tags. After that period it will clean up and then be disabled again.
  # A value of about 1000 can significantly improve overall performance.
  # The memory usage normally does not increase.
  # Depending on the work done for every xml tag the value might have to be adjusted.
  # 
  def instantiate(str, gcSuspendCount=0)
    gcDisabledBefore = GC.disable
    gcSuspendCount = 0 if gcDisabledBefore
    begin
      visitor = Visitor.new(self, gcSuspendCount)
      parser = Nokogiri::XML::SAX::Parser.new(visitor)
      parser.parse(str) do |ctx|
        @parserContext = ctx
      end
     ensure 
      GC.enable unless gcDisabledBefore
    end
  end
  
  def text(str)
  end
end
