# RGen Framework
# (c) Martin Thiede, 2006

require 'rgen/template_language/template_container'
require 'rgen/template_language/template_helper'

module RGen
  
module TemplateLanguage
    
class DirectoryTemplateContainer
  include TemplateHelper
  
  def initialize(metamodel=nil, output_path=nil, parent=nil)
    @containers = {}
    @directoryContainers = {}
    @parent = parent
    @metamodel = metamodel
    @output_path = output_path
  end
  
  def load(dir)
    Dir.foreach(dir) { |f|
      qf = dir+"/"+f
      if !File.directory?(qf) && f =~ /^(.*)\.tpl$/
       (@containers[$1] = TemplateContainer.new(@metamodel, @output_path, self,qf)).load
      elsif File.directory?(qf) && f != "." && f != ".."
       (@directoryContainers[f] = DirectoryTemplateContainer.new(@metamodel, @output_path, self)).load(qf)
      end
    }
  end
  
  def expand(template, *all_args)
    if template =~ /^\//
      if @parent
        # pass to parent
        @parent.expand(template, *all_args)
      else
        # this is root
        _expand(template, *all_args)
      end
    elsif template =~ /^\.\.\/(.*)/
      if @parent
        # pass to parent
        @parent.expand($1, *all_args)
      else
        raise "No parent directory for root"
      end
    else
      _expand(template, *all_args)
    end
  end
  
  # Set indentation string.
  # Every generated line will be prependend with n times this string at an indentation level of n.
  # Defaults to "   " (3 spaces)
  def indentString=(str)
    @indentString = str
  end
  
  def indentString
    @indentString || (@parent && @parent.indentString) || "   "
  end
  
  private
  
  def _expand(template, *all_args)
    if template =~ /^\/?(\w+)::(\w.*)/ 
      raise "Template not found: #{$1}" unless @containers[$1]
      @containers[$1].expand($2, *all_args)
    elsif template =~ /^\/?(\w+)\/(\w.*)/ 
      raise "Template not found: #{$1}" unless @directoryContainers[$1]
      @directoryContainers[$1].expand($2, *all_args)
    else
      raise "Invalid template name: #{template}"
    end
  end
  
end

end
    
end