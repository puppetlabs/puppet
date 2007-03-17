def deprecated(&block)
  block.call unless ENV['RSPEC_DISABLE_DEPRECATED_FEATURES'] == 'true'
end
