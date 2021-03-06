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

require 'bundler/gem_tasks'

desc 'Generate Ruby documentation'
task :yard do
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    t.files = ['**/*.rb', '-', 'README.md', 'LICENSE']
    t.stats_options = %w(--list-undoc)
  end
end

task doc: %w(yard)

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)
task default: [:spec]

begin
  require "rubocop/rake_task"

  Rake::Task[:default].enhance [:rubocop]

  RuboCop::RakeTask.new do |task|
    task.options << "--display-cop-names"
  end
rescue LoadError
end
