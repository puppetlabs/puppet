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
          results << if RUBY_VERSION >= "1.9" then
              line.join
            else
              line.pack "c*"
            end
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
    file.sub('lib/puppet', d).sub('.rb', '_spec.rb')
  }.find_all { |f|
    FileTest.exist?(f)
  }
end

def run_spec(command)
  clear
  result = run_comp(command).split("\n").last
  status = result.include?('0 failures') ? :pass : :fail
  growl result, status
end

def run_spec_files(files)
  files = Array(files)
  return if files.empty?
  opts = File.readlines('spec/spec.opts').collect { |l| l.chomp }.join(" ")
  begin
    run_spec("rspec #{files.join(' ')}")
  rescue => detail
    puts detail.backtrace
    warn "Failed to run #{files.join(', ')}: #{detail}"
  end
end

def run_suite
  files = files("unit") + files("integration")
  run_spec("rspec #{files.join(' ')}")
end

def files(dir)
  require 'find'

  result = []
  Find.find(File.join("spec", dir)) do |path|
    result << path if path =~ /\.rb/
  end
  
  result
end

watch('spec/spec_helper.rb') { run_suite }
watch(%r{^spec/(unit|integration)/.*\.rb$}) { |md| run_spec_files(md[0]) }
watch(%r{^lib/puppet/(.*)\.rb$}) { |md|
  run_spec_files(file2specs(md[0]))
}
watch(%r{^spec/lib/spec.*}) { |md| run_suite }
watch(%r{^spec/lib/monkey_patches/.*}) { |md| run_suite }

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
    begin
      run_suite
    rescue => detail
      puts detail.backtrace
      puts "Could not run suite: #{detail}"
    end
  end
end
