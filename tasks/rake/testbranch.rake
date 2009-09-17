desc "Rebuild the 'test' branch"
task :testbranch do
    TEST_SERIES = %x{git config --get puppet.testseriesfile}.chomp

    sh 'git checkout master'
    if %x{git branch}.split("\n").detect { |l| l =~ /\s+test$/ }
        sh 'git branch -D test'
    end
    sh 'git checkout -b test'
    File.readlines(TEST_SERIES).each do |line|
        line.chomp!

        # Always create a commit for our merge
        sh "git merge --no-ff #{line}"
    end
end
