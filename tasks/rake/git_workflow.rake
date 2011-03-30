# This set of tasks helps automate the workflow as described on
# http://projects.puppetlabs.com/projects/puppet/wiki/Development_Lifecycle


def find_start(start)
# This is a case statement, as we might want to map certain
# git tags to starting points that are not currently in git.
  case start
    when nil?;
    when @next_release; return "master"
    else return start
  end
end

desc "Set up git for working with Puppet"
task :git_setup do
  # This should be changed as new versions get released
  @next_release = '0.26.x'
  @remote = {}
  default_remote = {}
  default_remote[:url] = 'git://github.com/reductivelabs/puppet'
  default_remote[:name] = 'origin'
  @remote[:name] = %x{git config puppet.defaultremote}.chomp
  @remote[:name] = @remote[:name].empty? ? default_remote[:name] : @remote[:name]
  @remote[:url] = default_remote[:url] if @remote[:name] == default_remote[:name]
  default_fetch = '+refs/heads/*:refs/remotes/puppet/*'
  @remote[:fetch] = %x{git config puppet.#{@remote[:name]}.fetch}.chomp
  @remote[:fetch] = @remote[:fetch].empty? ?  default_fetch : @remote[:fetch]
end

desc "Start work on a feature"
task :start_feature, [:feature,:remote,:branch] => :git_setup do |t, args|
  args.with_defaults(:remote => @remote[:name])
  args.with_defaults(:branch => @next_release)
  start_at = find_start(args.branch)
  branch = "feature/#{start_at}/#{args.feature}"
  sh "git checkout -b #{branch} #{start_at}" do |ok, res|
    if ! ok
      raise <<EOS
Was not able to create branch for #{args.feature} on branch #{args.branch}, starting at #{start_at}: error code was: #{res.exitstatus}
EOS
    end
  end
  sh "git config branch.#{branch}.remote #{args.remote}" do |ok, res|
    raise "Could not set remote: #{$?}" unless ok
  end

  sh "git config branch.#{branch}.merge refs/heads/#{branch}" do |ok, res|
    raise "Could not configure merge: #{$?}" unless ok
  end
end

desc "Do git prep to start work on a Redmine ticket"
task :start_ticket, [:ticket, :remote, :branch] => :git_setup do |t, args|
  args.with_defaults(:remote => @remote[:name])
  args.with_defaults(:branch => @next_release)
  start_at = find_start(args.branch)
  branch = "tickets/#{start_at}/#{args.ticket}"
  sh "git checkout -b #{branch} #{start_at}" do |ok, res|
    unless ok
      raise <<EOS
Was not able to create branch for ticket #{args.ticket} on branch #{args.branch}, starting at #{start_at}: error code was: #{$?}
Git command used was: #{command}
EOS
    end
  end
    sh "git config branch.#{branch}.remote #{args.remote}" do |ok, res|
      raise "Could not set remote: #{$?}" unless ok
  end

    sh "git config branch.#{branch}.merge refs/heads/#{branch}" do |ok, res|
      raise "Could not configure merge: #{$?}" unless ok
  end
end

# This isn't very useful by itself, but we might enhance it later, or use it
# in a dependency for a more complex task.
desc "Push out changes"
task :push_changes, [:remote] do |t, arg|
  branch = %x{git branch | grep "^" | awk '{print $2}'}
  sh "git push #{arg.remote} #{branch}" do |ok, res|
    raise "Unable to push to #{arg.remote}" unless ok
  end
end

desc "Send patch information to the puppet-dev list"
task :mail_patches do
    if Dir.glob("00*.patch").length > 0
        raise "Patches already exist matching '00*.patch'; clean up first"
    end

    unless %x{git status} =~ /On branch (.+)/
        raise "Could not get branch from 'git status'"
    end
    branch = $1

    unless branch =~ %r{^([^\/]+)/([^\/]+)/([^\/]+)$}
        raise "Branch name does not follow <type>/<parent>/<name> model; cannot autodetect parent branch"
    end

    type, parent, name = $1, $2, $3

    # Create all of the patches
    sh "git format-patch -C -M -s -n --subject-prefix='PATCH/puppet' #{parent}..HEAD"

    # Add info to the patches
    additional_info = "Local-branch: #{branch}\n"
    files = Dir.glob("00*.patch")
    files.each do |file|
        contents = File.read(file)
        contents.sub!(/^---\n/, "---\n#{additional_info}")
        File.open(file, 'w') do |file_handle|
            file_handle.print contents
        end
    end

    # And then mail them out.

    # If we've got more than one patch, add --compose
    if files.length > 1
        compose = "--compose"
        subject = "--subject \"#{type} #{name} against #{parent}\""
    else
        compose = ""
        subject = ""
    end

    # Now send the mail.
    sh "git send-email #{compose} #{subject} --no-signed-off-by-cc --suppress-from --to puppet-dev@googlegroups.com 00*.patch"

    # Finally, clean up the patches
    sh "rm 00*.patch"
end

