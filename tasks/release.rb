
VERSION_FILE = 'lib/hiera.rb'

def get_current_version
  File.open( VERSION_FILE ) {|io| io.grep(/VERSION = /)}[0].split()[-1]
end

def described_version
    # This ugly bit removes the gSHA1 portion of the describe as that causes failing tests
    %x{git describe}.gsub('-', '.').split('.')[0..3].join('.').to_s.gsub('v', '')
end

namespace :pkg do

  desc "Build Package"
  task :release => [ :default ] do
    Rake::Task[:package].invoke
  end

end # namespace

task :clean => [ :clobber_package ] do
end
