# RGen Framework
# (c) Martin Thiede, 2006

require 'erb'
require 'fileutils'
require 'rgen/template_language/output_handler'
require 'rgen/template_language/template_helper'

module RGen
  
  module TemplateLanguage
    
    class TemplateContainer
      include TemplateHelper
      
      def initialize(metamodels, output_path, parent, filename)
        @templates = {}
        @parent = parent
        @filename = filename
        @indent = 0
        @output_path = output_path
    		@metamodels = metamodels
    		@metamodels = [ @metamodels ] unless @metamodels.is_a?(Array)
      end
      
      def load
    		File.open(@filename,"rb") do |f|
          begin
  	      	@@metamodels = @metamodels
    	    	fileContent = f.read
      	  	_detectNewLinePattern(fileContent)
        		ERB.new(fileContent,nil,nil,'@output').result(binding)
          rescue Exception => e
            processAndRaise(e)
          end
    		end
      end
      
      def expand(template, *all_args)
        args, params = _splitArgsAndOptions(all_args)
    		if params.has_key?(:foreach)
      		raise StandardError.new("expand :foreach argument is not enumerable") \
        		unless params[:foreach].is_a?(Enumerable)
          _expand_foreach(template, args, params)
        else
          _expand(template, args, params)
        end
      end
      
      def evaluate(template, *all_args)
        args, params = _splitArgsAndOptions(all_args)
        raise StandardError.new(":foreach can not be used with evaluate") if params[:foreach]
        _expand(template, args, params.merge({:_evalOnly => true}))
      end
      
      def this
        @context
      end
      
      def method_missing(name, *args)
        @context.send(name, *args)
      end
      
      def self.const_missing(name)
        super unless @@metamodels
        @@metamodels.each do |mm|
          return mm.const_get(name) rescue NameError
        end
        super
      end
      
      private
      
      def nonl
        @output.ignoreNextNL
      end
      
      def nows
        @output.ignoreNextWS
      end
      
      def nl
    		_direct_concat(@newLinePattern)
      end
      
      def ws
        _direct_concat(" ")
      end
      
      def iinc
        @indent += 1
        @output.indent = @indent
      end
      
      def idec
        @indent -= 1 if @indent > 0
        @output.indent = @indent
      end
      
      TemplateDesc = Struct.new(:block, :local)
      
      def define(template, params={}, &block)
        _define(template, params, &block)
      end
      
      def define_local(template, params={}, &block)
        _define(template, params.merge({:local => true}), &block)
      end
      
      def file(name, indentString=nil)
        old_output, @output = @output, OutputHandler.new(@indent, indentString || @parent.indentString)
        begin
          yield
        rescue Exception => e
          processAndRaise(e)
        end
        path = ""
        path += @output_path+"/" if @output_path
        dirname = File.dirname(path+name)
        FileUtils.makedirs(dirname) unless File.exist?(dirname)
    		File.open(path+name,"wb") { |f| f.write(@output) }
        @output = old_output
      end
      
      # private private
      
      def _define(template, params={}, &block)
        @templates[template] ||= {}
        cls = params[:for] || Object
        @templates[template][cls] = TemplateDesc.new(block, params[:local])
      end
      
      def _expand_foreach(template, args, params)
        sep = params[:separator]
        params[:foreach].each_with_index {|e,i|
          _direct_concat(sep.to_s) if sep && i > 0 
          output = _expand(template, args, params.merge({:for => e}))
        }
      end
      
      LOCAL_TEMPLATE_REGEX = /^:*(\w+)$/
      
      def _expand(template, args, params)
        raise StandardError.new("expand :for argument evaluates to nil") if params.has_key?(:for) && params[:for].nil?
        context = params[:for]
        old_indent = @indent
        @indent = params[:indent] || @indent
        noIndentNextLine = params[:_noIndentNextLine] || 
          (@output.is_a?(OutputHandler) && @output.noIndentNextLine) || 
          (@output.to_s.size > 0 && @output.to_s[-1] != "\n"[0]) 
        caller = params[:_caller] || self
        old_context, @context = @context, context if context
        local_output = nil
        if template =~ LOCAL_TEMPLATE_REGEX
          tplname = $1
          raise StandardError.new("Template not found: #{$1}") unless @templates[tplname]
          old_output, @output = @output, OutputHandler.new(@indent, @parent.indentString)
          @output.noIndentNextLine = noIndentNextLine
          _call_template(tplname, @context, args, caller == self)
          old_output.noIndentNextLine = false if old_output.is_a?(OutputHandler) && !old_output.noIndentNextLine
          local_output, @output = @output, old_output
        else
          local_output = @parent.expand(template, *(args.dup << {:for => @context, :indent => @indent, :_noIndentNextLine => noIndentNextLine, :_evalOnly => true, :_caller => caller}))
        end
        _direct_concat(local_output) unless params[:_evalOnly]
        @context = old_context if old_context
        @indent = old_indent
        local_output.to_s
      end
      
      def processAndRaise(e, tpl=nil)
        bt = e.backtrace.dup
        e.backtrace.each_with_index do |t,i|
          if t =~ /\(erb\):(\d+):/
            bt[i] = "#{@filename}:#{$1}"
            bt[i] += ":in '#{tpl}'" if tpl
            break
          end
        end
        raise e, e.to_s, bt
      end
      
      def _call_template(tpl, context, args, localCall)
        found = false
        @templates[tpl].each_pair do |key, value| 
          if context.is_a?(key)
            templateDesc = @templates[tpl][key]
            proc = templateDesc.block
            arity = proc.arity
            arity = 0 if arity == -1	# if no args are given
            raise StandardError.new("Wrong number of arguments calling template #{tpl}: #{args.size} for #{arity} "+
              "(Beware: Hashes as last arguments are taken as options and are ignored)") \
              if arity != args.size
            raise StandardError.new("Template can only be called locally: #{tpl}") \
              if templateDesc.local && !localCall
            begin
             	@@metamodels = @metamodels
              proc.call(*args) 
            rescue Exception => e
              processAndRaise(e, tpl)
            end
            found = true
          end
        end
        raise StandardError.new("Template class not matching: #{tpl} for #{context.class.name}") unless found
      end
        
      def _direct_concat(s)
        if @output.is_a? OutputHandler
          @output.direct_concat(s)
        else
          @output << s
        end
      end 
      def _detectNewLinePattern(text)
        tests = 0
        rnOccurances = 0
        text.scan(/(\r?)\n/) do |groups|
          tests += 1
          rnOccurances += 1 if groups[0] == "\r"
          break if tests >= 10
        end
        if rnOccurances > (tests / 2)
          @newLinePattern = "\r\n"
        else
          @newLinePattern = "\n"
        end
      end
              
    end
    
  end
  
end
