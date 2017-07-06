# RGen Framework
# (c) Martin Thiede, 2006

require 'rgen/template_language/directory_template_container'
require 'rgen/template_language/template_container'

module RGen

# The RGen template language has been designed to build complex generators.
# It is very similar to the EXPAND language of the Java based
# OpenArchitectureWare framework.
# 
# =Templates
# 
# The basic idea is to allow "templates" not only being template files
# but smaller parts. Those parts can be expanded from other parts very 
# much like Ruby methods are called from other methods.
# Thus the term "template" refers to such a part within a "template file".
# 
# Template files used by the RGen template language should have a 
# filename with the postfix ".tpl". Those files can reside within (nested)
# template file directories.
# 
# As an example a template directory could look like the following:
# 
#   templates/root.tpl
#   templates/dbaccess/dbaccess.tpl
#   templates/dbaccess/schema.tpl
#   templates/headers/generic_headers.tpl
#   templates/headers/specific/component.tpl
# 
# A template is always called for a <i>context object</i>. The context object
# serves as the receiver of methods called within the template. Details are given
# below.
# 
# 
# =Defining Templates
# 
# One or more templates can be defined in a template file using the +define+
# keyword as in the following example:
# 
#   <% define 'GenerateDBAdapter', :for => DBDescription do |dbtype| %>
#     Content to be generated; use ERB syntax here
#   <% end %>
#   
# The template definition takes three kinds of parameters:
# 1. The name of the template within the template file as a String or Symbol
# 2. An optional class object describing the class of context objects for which
#    this template is valid.
# 3. An arbitrary number of template parameters
# See RGen::TemplateLanguage::TemplateContainer for details about the syntax of +define+.
# 
# Within a template, regular ERB syntax can be used. This is
# * <code><%</code> and <code>%></code> are used to embed Ruby code
# * <code><%=</code> and <code>%></code> are used to embed Ruby expressions with
#   the expression result being written to the template output
# * <code><%#</code> and <code>%></code> are used for comments
# All content not within these tags is written to the template output verbatim.
# See below for details about output files and output formatting.
# 
# All methods which are called from within the template are sent to the context
# object.
#
# Experience shows that one easily forgets the +do+ at the end of the first 
# line of a template definition. This will result in an ERB parse error.
# 
# 
# =Expanding Templates
# 
# Templates are normally expanded from within other templates. The only
# exception is the root template, which is expanded from the surrounding code.
# 
# Template names can be specified in the following ways:
# * Non qualified name: use the template with the given name in the current template file
# * Relative qualified name: use the template within the template file specified by the relative path
# * Absolute qualified name: use the template within the template file specified by the absolute path
# 
# The +expand+ keyword is used to expand templates. 
# 
# Here are some examples:
# 
#   <% expand 'GenerateDBAdapter', dbtype, :for => dbDesc %>
# 
# <i>Non qualified</i>. Must be called within the file where 'GenerateDBAdapter' is defined.
# There is one template parameter passed in via variable +dbtype+.
# The context object is provided in variable +dbDesc+.
#  
#   <% expand 'dbaccess::ExampleSQL' %>
# 
# <i>Qualified with filename</i>. Must be called from a file in the same directory as 'dbaccess.tpl'
# There are no parameters. The current context object will be used as the context 
# object for this template expansion.
# 
#   <% expand '../headers/generic_headers::CHeader', :foreach => modules %>
# 
# <i>Relatively qualified</i>. Must be called from a location from which the file
# 'generic_headers.tpl' is accessible via the relative path '../headers'.
# The template is expanded for each module in +modules+ (which has to be an Array).
# Each element of +modules+ will be the context object in turn.
# 
#   <% expand '/headers/generic_headers::CHeader', :foreach => modules %>
# 
# Absolutely qualified: The same behaviour as before but with an absolute path from
# the template directory root (which in this example is 'templates', see above)
# 
# Sometimes it is neccessary to generate some text (e.g. a ',') in between the single
# template expansion results from a <code>:foreach</code> expansion. This can be achieved by
# using the <code>:separator</code> keyword:
# 
#   <% expand 'ColumnName', :foreach => column, :separator => ', ' %>
#   
# Note that the separator may also contain newline characters (\n). See below for
# details about formatting.
# 
# 
# =Formatting
# 
# For many generator tools a formatting postprocess (e.g. using a pretty printer) is 
# required in order to make the output readable. However, depending on the kind of
# generated output, such a tool might not be available.
# 
# The RGen template language has been design for generators which do not need a
# postprocessing step. The basic idea is to eliminate all whitespace at the beginning
# of template lines (the indentation that makes the _template_ readable) and output
# newlines only after at least on character has been generated in the corresponding
# line. This way there are no empty lines in the output and each line will start with
# a non-whitspace character.
# 
# Starting from this point one can add indentation and newlines as required by using
# explicit formatting commands:
# * <code><%nl%></code> (newline) starts a new line
# * <code><%iinc%></code> (indentation increment) increases the current indentation
# * <code><%idec%></code> (indentation decrement) decreases the current indentation
# * <code><%nonl%></code> (no newline) ignore next newline
# * <code><%nows%></code> (no whitespace) ignore next whitespace
# 
# Indentation takes place for every new line in the output unless it is 0.
# The initial indentation can be specified with a root +expand+ command by using
# the <code>:indent</code> keyword.
# 
# Here is an example:
# 
#   expand 'GenerateDBAdapter', dbtype, :for => dbDesc, :indent => 1
#   
# Initial indentation defaults to 0. Normally <code><%iinc%></code> and 
# <code><%idec%></code> are used to change the indentation.
# The current indentation is kept for expansion of subtemplates.
#
# The string which is used to realize one indentation step can be set using
# DirectoryTemplateContainer#indentString or with the template language +file+ command.
# The default is "   " (3 spaces), the indentation string given at a +file+ command
# overwrites the container's default which in turn overwrites the overall default.
# 
# Note that commands to ignore whitespace and newlines are still useful if output 
# generated from multiple template lines should show up in one single output line.
# 
# Here is an example of a template generating a C program:
# 
#   #include <stdio.h>
#   <%nl%>
#   int main() {<%iinc%>
#     printf("Hello World\n");
#     return 0;<%idec>
#   }
#   
# The result is:
# 
#   #include <stdio.h>
#   
#   int main() {
#      printf("Hello World\n");
#      return 0;
#   }
# 
# Note that without the explicit formatting commands, the output generated from the 
# example above would not have any empty lines or whitespace in the beginning of lines.
# This may seem like unneccessary extra work for the example above which could also
# have been generated by passing the template to the output verbatimly.
# However in most cases templates will contain more template specific indentation and
# newlines which should be eliminated than formatting that should be visible in the 
# output.
# 
# Here is a more realistic example for generating C function prototypes:
# 
#   <% define 'Prototype', :for => CFunction do %>
#     <%= getType.name %> <%= name %>(<%nows%>
#       <% expand 'Signature', :foreach => argument, :separator => ', ' %>);
#   <% end %>
#   
#   <% define 'Signature', :for => CFunctionArgument do %>
#     <%= getType.name %> <%= name%><%nows%>
#   <% end %>
#   
# The result could look something like:
# 
#   void somefunc(int a, float b, int c);
#   int otherfunc(short x);
# 
# In this example a separator is used to join the single arguments of the C functions.
# Note that the template generating the argument type and name needs to contain
# a <code><%nows%></code> if the result should consist of a single line.
# 
# Here is one more example for generating C array initializations:
# 
#   <% define 'Array', :for => CArray do %>
#     <%= getType.name %> <%= name %>[<%= size %>] = {<%iinc%>
#       <% expand 'InitValue', :foreach => initvalue, :separator => ",\n" %><%nl%><%idec%>
#     };
#   <% end %>
#   
#   <% define 'InitValue', :for => PrimitiveInitValue do %>
#     <%= value %><%nows%>
#   <% end %>
# 
# The result could look something like:
# 
#   int myArray[3] = {
#      1,
#      2,
#      3
#   };
# 
# Note that in this example, the separator contains a newline. The current increment
# will be applied to each single expansion result since it starts in a new line.
# 
# 
# =Output Files
# 
# Normally the generated content is to be written into one or more output files.
# The RGen template language facilitates this by means of the +file+ keyword.
# 
# When the +file+ keyword is used to define a block, all output generated
# from template code within this block will be written to the specified file.
# This includes output generated from template expansions.
# Thus all output from templates expanded within this block is written to
# the same file as long as those templates do not use the +file+ keyword to 
# define a new file context.
# 
# Here is an example:
# 
#   <% file 'dbadapter/'+adapter.name+'.c' do %>
#     all content within this block will be written to the specified file
#   <% end %>
# 
# Note that the filename itself can be calculated dynamically by an arbitrary
# Ruby expression.
# 
# The absolute position where the output file is created depends on the output
# root directory passed to DirectoryTemplateContainer as described below.
#
# As a second argument, the +file+ command can take the indentation string which is
# used to indent output lines (see Formatting).
# 
# =Setting up the Generator
# 
# Setting up the generator consists of 3 steps:
# * Instantiate DirectoryTemplateContainer passing one or more metamodel(s) and the output 
#   directory to the constructor.
# * Load the templates into the template container
# * Expand the root template to start generation
# 
# Here is an example:
#
#   module MyMM
#     # metaclasses are defined here, e.g. using RGen::MetamodelBuilder
#   end
# 
#   OUTPUT_DIR = File.dirname(__FILE__)+"/output"
#   TEMPLATES_DIR = File.dirname(__FILE__)+"/templates"
# 
#   tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new(MyMM, OUTPUT_DIR)
#   tc.load(TEMPLATES_DIR)
#   # testModel should hold an instance of the metamodel class expected by the root template
#   # the following line starts generation
#   tc.expand('root::Root', :for => testModel, :indent => 1)
# 
# The metamodel is the Ruby module which contains the metaclasses.
# This information is required for the template container in order to resolve the
# metamodel classes used within the template file. 
# If several metamodels shall be used, an array of modules can be passed instead
# of a single module.
# 
# The output path is prepended to the relative paths provided to the +file+ 
# definitions in the template files.
#
# The template directory should contain template files as described above.
#
# Finally the generation process is started by calling +expand+ in the same way as it
# is used from within templates.
# 
# Also see the unit tests for more examples.
# 
module TemplateLanguage

end

end