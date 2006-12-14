require 'puppet/rails/lib/acts_as_taggable'
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Taggable)

require 'puppet/rails/lib/tagging'
require 'puppet/rails/lib/tag'
