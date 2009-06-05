function = Puppet::Util::Reference.newreference :function, :doc => "All functions available in the parser" do
    Puppet::Parser::Functions.functiondocs
end
function.header = "
There are two types of functions in Puppet: Statements and rvalues.
Statements stand on their own and do not return arguments; they are used for
performing stand-alone work like importing.  Rvalues return values and can
only be used in a statement requiring a value, such as an assignment or a case
statement.

Here are the functions available in Puppet:

"
