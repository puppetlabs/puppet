test_name "verify we can print the function reference"

tag 'audit:low',
    'audit:unit',
    'audit:delete'

on(agents, puppet_doc("-r", "function")) do
    fail_test "didn't print function reference" unless
        stdout.include? 'Function Reference'
end
