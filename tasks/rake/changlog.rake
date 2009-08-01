desc "Create a ChangeLog based on git commits."
task :changelog do
    CHANGELOG_DIR = "#{Dir.pwd}"
    mkdir(CHANGELOG_DIR) unless File.directory?(CHANGELOG_DIR)
    change_body=`git log --pretty=format:'%aD%n%an <%ae>%n%s%n'`
    File.open(File.join(CHANGELOG_DIR, "ChangeLog"), 'w') do |f|
        f << change_body
    end
end

