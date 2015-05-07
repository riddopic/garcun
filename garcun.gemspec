# encoding: UTF-8
#
# Author:    Stefano Harding <riddopic@gmail.com>
# License:   Apache License, Version 2.0
# Copyright: (C) 2014-2015 Stefano Harding
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'garcon/version'

Gem::Specification.new do |gem|
  gem.name        =   'garcun'
  gem.version     =    Garcon::VERSION.dup
  gem.authors     = [ 'Stefano Harding' ]
  gem.email       = [ 'riddopic@gmail.com' ]
  gem.description =   'A useful collection of methods to make cooking more fun'
  gem.summary     =    gem.description
  gem.homepage    =   'https://github.com/riddopic/garcun'
  gem.license     =   'Apache 2.0'

  gem.require_paths         = %w[lib]
  gem.files                 = `git ls-files`.split($/)
  gem.test_files            = `git ls-files -- spec`.split($/)
  gem.extra_rdoc_files      = %w[LICENSE README.md]
  gem.required_ruby_version = '>= 2.0.0'

  gem.add_dependency 'chef',           '>= 11.0'
  gem.add_dependency 'bundler'

  # Development gems
  gem.add_development_dependency 'rake',        '~> 10.4'
  gem.add_development_dependency 'yard',        '~> 0.8'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'stove',       '~> 3.2', '>= 3.2.3'
  gem.add_development_dependency 'thor'

  # Test gems
  gem.add_development_dependency 'rspec',       '~> 3.2'
  gem.add_development_dependency 'rspec-its',   '~> 1.2'
  gem.add_development_dependency 'chefspec',    '~> 4.2'
  gem.add_development_dependency 'fuubar',      '~> 2.0'
  gem.add_development_dependency 'simplecov',   '~> 0.9'
  gem.add_development_dependency 'foodcritic',  '~> 4.0'
  gem.add_development_dependency 'berkshelf',   '~> 3.2'
  gem.add_development_dependency 'serverspec'
  gem.add_development_dependency 'inch'
  gem.add_development_dependency 'yardstick'
  gem.add_development_dependency 'guard'
  gem.add_development_dependency 'guard-shell'
  gem.add_development_dependency 'guard-yard'
  gem.add_development_dependency 'guard-rubocop'
  gem.add_development_dependency 'guard-foodcritic'
  gem.add_development_dependency 'guard-kitchen'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'ruby_gntp'

  # Integration gems
  gem.add_development_dependency 'test-kitchen',    '~> 1.3'
  gem.add_development_dependency 'kitchen-vagrant'
  gem.add_development_dependency 'vagrant-wrapper'
  gem.add_development_dependency 'kitchen-docker'
  gem.add_development_dependency 'kitchen-sync'
  gem.add_development_dependency 'rubocop'
  gem.add_development_dependency 'geminabox-rake'

  # Versioning
  gem.add_development_dependency 'version'
  gem.add_development_dependency 'thor-scmversion'
  gem.add_development_dependency 'semverse'
end
