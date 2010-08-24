Puppet::Parser::Functions::newfunction(:inline_template, :type => :rvalue, :doc =>
  "Evaluate a template string and return its value.  See 
  [the templating docs](http://docs.puppetlabs.com/guides/templating.html) for 
  more information.  Note that if multiple template strings are specified, their 
  output is all concatenated and returned as the output of the function.") do |vals|
  
  require 'erb'

    vals.collect do |string|
      # Use a wrapper, so the template can't get access to the full
      # Scope object.

      wrapper = Puppet::Parser::TemplateWrapper.new(self)
      begin
        wrapper.result(string)
      rescue => detail
        raise Puppet::ParseError,
          "Failed to parse inline template: #{detail}"
      end
    end.join("")
end
