require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rake/gempackagetask'

require File.dirname(__FILE__) + '/lib/thin'

CLEAN.include %w(doc/rdoc pkg)

Rake::TestTask.new do |t|
  t.pattern = 'test/*_test.rb'
end
task :default => :test

spec = Gem::Specification.new do |s|
  s.name                  = Thin::NAME
  s.version               = Thin::VERSION
  s.platform              = Gem::Platform::RUBY
  s.summary               = "Thin and fast web server"
  s.description           = s.summary
  s.author                = "Marc-Andre Cournoyer"
  s.email                 = 'macournoyer@gmail.com'
  s.homepage              = 'http://code.macournoyer.com/thin/'
  s.executables           = %w(thin)

  s.required_ruby_version = '>= 1.8.2'

  s.files                 = %w(COPYING README Rakefile) + Dir.glob("{bin,doc,test,lib}/**/*")
  
  s.require_path          = "lib"
  s.bindir                = "bin"
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end
