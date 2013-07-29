#!/usr/bin/env ruby
# Author: Nick Lewis

specs_in_order = File.read('spec_order.txt').split

failing_spec = ARGV.first

specs = specs_in_order[0...specs_in_order.index(failing_spec)]

suspects = specs

while suspects.length > 1 do
  count = suspects.length
  specs_to_run = suspects[0...(count/2)]
  puts "Trying #{specs_to_run.join(' ')}"
  start = Time.now
  system("bundle exec rspec #{specs_to_run.join(' ')} #{failing_spec}")
  puts "Finished in #{Time.now - start} seconds"
  if $? == 0
    puts "This group is innocent. The culprit is in the other half."
    suspects = suspects[(count/2)..-1]
  else
    puts "One of these is guilty."
    suspects = specs_to_run
  end
end

puts "The culprit is #{suspects.first}"
