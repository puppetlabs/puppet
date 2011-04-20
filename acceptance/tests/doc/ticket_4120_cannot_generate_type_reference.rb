test_name "verify we can print the function reference"
on(agents, puppet_doc("-r", "type")) do
    fail_test "didn't print type reference" unless
        stdout.include? 'Type Reference'
end
