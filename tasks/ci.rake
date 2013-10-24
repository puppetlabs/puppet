namespace "ci" do
  task :spec do
    ENV["LOG_SPEC_ORDER"] = "true"
    sh %{rspec -r yarjuf -f JUnit -o result.xml -fd spec}
  end

  desc "Tar up the acceptance/ directory so that package test runs have tests to run against."
  task :acceptance_artifacts do
    Dir.chdir("acceptance") do
      rm_f "acceptance-artifacts.tar.gz"
      sh "tar -czv --exclude .bundle -f acceptance-artifacts.tar.gz *"
    end
  end
end
