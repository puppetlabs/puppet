class b {}

# if the files are evaluated in the wrong order, the file 'b' has a reference
# to $a (set in file 'a') and with strict variable lookup should raise an error
# and fail this test.
$b = $a # error if $a not set in strict mode
