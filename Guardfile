# A sample Guardfile
# More info at https://github.com/guard/guard#readme
# vim: ft=ruby

guard 'rspec', :version => 2 do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/puppet/(.+)\.rb$})      { |m| "spec/unit/#{m[1]}_spec.rb" }
  watch(%r{^lib/puppet/(.*)/(.*)\.rb$}) { |m| "spec/integration/#{m[1]}"  }
  watch('spec/spec_helper.rb')          {     "spec"                      }
end

