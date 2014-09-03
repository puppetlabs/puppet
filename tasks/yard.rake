begin
  require 'yard'

  namespace :doc do
    desc "Clean up generated documentation"
    task :clean do
      rm_rf "doc"
    end

    desc "Generate public documentation pages for the API"
    YARD::Rake::YardocTask.new(:api) do |t|
      t.files = ['lib/**/*.rb']
      t.options = %w{
        --protected
        --private
        --verbose
        --markup markdown
        --readme README.md
        --tag status
        --transitive-tag status
        --tag comment
        --hide-tag comment
        --tag dsl:"DSL"
        --no-transitive-tag api
        --template-path yardoc/templates
        --files README_DEVELOPER.md,CO*.md,api/**/*.md
        --api public
        --api private
        --hide-void-return
      }
    end

    desc "Generate documentation pages for all of the code"
    YARD::Rake::YardocTask.new(:all) do |t|
      t.files = ['lib/**/*.rb']
      t.options = %w{
        --verbose
        --markup markdown
        --readme README.md
        --tag status
        --transitive-tag status
        --tag comment
        --hide-tag comment
        --tag dsl:"DSL"
        --no-transitive-tag api
        --template-path yardoc/templates
        --files README_DEVELOPER.md,CO*.md,api/**/*.md
        --api public
        --api private
        --no-api
        --hide-void-return
      }
    end
  end
rescue LoadError => e
  if verbose
    STDERR.puts "Document generation not available without yard. #{e.message}"
  end
end
