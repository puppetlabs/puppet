ENV["WATCHR"] = "1"
ENV['AUTOTEST'] = 'true'

def run_comp(cmd)
  puts cmd
  results = []
  old_sync = $stdout.sync
  $stdout.sync = true
  line = []
  begin
    open("| #{cmd}", "r") do |f|
      until f.eof? do
        c = f.getc
        putc c
        line << c
        if c == ?\n
          results << line.join
          line.clear
        end
      end
    end
  ensure
    $stdout.sync = old_sync
  end
  results.join
end

def clear
  #system("clear")
end

def growl(message, status)
  # Strip the color codes
  message.gsub!(/\[\d+m/, '')

  growlnotify = `which growlnotify`.chomp
  return if growlnotify.empty?
  title = "Watchr Test Results"
  image = status == :pass ? "autotest/images/pass.png" : "autotest/images/fail.png"
  options = "-w -n Watchr --image '#{File.expand_path(image)}' -m '#{message}' '#{title}'"
  system %(#{growlnotify} #{options} &)
end

def file2specs(file)
  %w{spec/unit spec/integration}.collect { |d|
    file.sub('lib/puppet', d).sub(".rb", "_spec.rb")
  }.find_all { |f|
    File.exist?(f)
  }
end

def file2test(file)
  result = file.sub('lib/puppet', 'test')
  return nil unless File.exist?(result)
  result
end

def run_spec(command)
  clear
  result = run_comp(command).split("\n").last
  status = result.include?('0 failures') ? :pass : :fail
  growl result, status
end

def run_test(command)
  clear
  result = run_comp(command).split("\n").last
  growl result.split("\n").last rescue nil
end

def run_test_file(file)
  run_test(%Q(#{file}))
end

def run_spec_files(files)
  files = Array(files)
  return if files.empty?
  begin
    # End users can put additional options into ~/.rspec
    run_spec("rspec --tty #{files.join(' ')}")
  rescue => detail
    puts "Failed to load #{files}: #{detail}"
  end
end

def run_all_tests
  run_test("rake unit")
end

def run_all_specs
  run_spec_files "spec"
end

def run_suite
  run_all_specs
  run_all_tests
end

watch('spec/spec_helper.rb') { run_all_specs }
watch(%r{^spec/(unit|integration)/.*\.rb$}) { |md| run_spec_files(md[0]) }
watch(%r{^lib/puppet/(.*)\.rb$}) { |md|
  run_spec_files(file2specs(md[0]))
  if t = file2test(md[0])
    run_test_file(t)
  end
}
watch(%r{^spec/lib/spec.*}) { |md| run_all_specs }
watch(%r{^spec/lib/monkey_patches/.*}) { |md| run_all_specs }
watch(%r{test/.+\.rb}) { |md|
  if md[0] =~ /\/lib\//
    run_all_tests
  else
    run_test_file(md[0])
  end
}

# Ctrl-\
Signal.trap 'QUIT' do
  puts " --- Running all tests ---\n\n"
  run_suite
end

@interrupted = false

# Ctrl-C
Signal.trap 'INT' do
  if @interrupted
    @wants_to_quit = true
    abort("\n")
  else
    puts "Interrupt a second time to quit; wait for rerun of tests"
    @interrupted = true
    Kernel.sleep 1.5
    # raise Interrupt, nil # let the run loop catch it
    run_suite
  end
end
