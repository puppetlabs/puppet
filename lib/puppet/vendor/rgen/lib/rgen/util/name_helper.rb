# RGen Framework
# (c) Martin Thiede, 2006

module RGen

module Util

module NameHelper

	def normalize(name)
		name.gsub(/\W/,'_')
	end
	
	def className(object)
		object.class.name =~ /::(\w+)$/; $1
	end
	
	def firstToUpper(str)
		str[0..0].upcase + ( str[1..-1] || "" )
	end
	
	def firstToLower(str)
		str[0..0].downcase + ( str[1..-1] || "" )
	end
	
	def saneClassName(str)
		firstToUpper(normalize(str)).sub(/^Class$/, 'Clazz')
	end
	
	def saneMethodName(str)
		firstToLower(normalize(str)).sub(/^class$/, 'clazz')
	end	
	
  def camelize(str)
    str.split(/[\W_]/).collect{|s| firstToUpper(s.downcase)}.join
  end
end

end

end

