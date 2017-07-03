test_name "verify we can print the function reference"

tag 'audit:low',
    'audit:unit',
    'audit:delete'

confine :except, :platform => /^eos-/

on(agents, puppet_doc("-r", "type")) do
    fail_test "didn't print type reference" unless
        stdout.include? 'Type Reference'
end
