# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rerun/version"

Gem::Specification.new do |s|
	s.name = "rerun"
	s.version = rerun::version
	s.authors = ["Patrick Yeon"]
	s.email = ['patrickyeon@gmail.com']
	s.homepage = 'https://github.com/patrickyeon/'
	s.summary = 'Catch up with old RSS feeds you missed'
	s.description = %q{TODO: Write description}

	s.rubyforge_project = 'rerun'

	s.files = `git ls-files`.split('\n')
	s.test_files = `git ls-files -- {test,spec,features}/*`.split('\n')
	s.executables = `git ls-files -- bin/*`.split('\n').map{ |f| File.basename(f) }
	s.require_paths = ['lib']
end
