Puppet::Parser::Functions::newfunction(:template, :type => :rvalue, :doc =>
    "Evaluate a template and return its value.  See `the templating docs
    <http://docs.puppetlabs.com/guides/templating.html>`_ for more information.  Note that
    if multiple templates are specified, their output is all concatenated
    and returned as the output of the function.") do |vals|
        require 'erb'

        vals.collect do |file|
            # Use a wrapper, so the template can't get access to the full
            # Scope object.
            debug "Retrieving template %s" % file

            wrapper = Puppet::Parser::TemplateWrapper.new(self)
            wrapper.file = file
            begin
                wrapper.result
            rescue => detail
                raise Puppet::ParseError,
                    "Failed to parse template %s: %s" %
                        [file, detail]
            end
        end.join("")
end
