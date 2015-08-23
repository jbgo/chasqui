# Newer versions of sidekiq only support newer versions of ruby
# https://github.com/mperham/sidekiq/blob/master/Changes.md#322
def sidekiq_supported_ruby_version?
  Gem::Version.new(RUBY_VERSION.dup) > Gem::Version.new('1.9.3')
end

if sidekiq_supported_ruby_version?
  require 'sidekiq'
end
