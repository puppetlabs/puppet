desc "Create a ChangeLog based on git commits."
task :changelog do
    begin
         gitc = %x{which git-changelog}
    rescue 
        puts "This task needs the git-changelog binary - http://github.com/ReinH/git-changelog"
    end

    CHANGELOG_DIR = "#{Dir.pwd}"
    mkdir(CHANGELOG_DIR) unless File.directory?(CHANGELOG_DIR)
    change_body = `git-changelog --limit=99999`
    File.open(File.join(CHANGELOG_DIR, "CHANGELOG"), 'w') do |f|
        f << change_body
    end
end
