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

require 'thread'
require 'tempfile'
require 'fileutils'

module Garcon
  # Class methods that are added when you include Garcon
  #
  module FileHelper
    # Methods are also available as module-level methods as well as a mixin.
    extend self

    # Checks in PATH returns true if the command is found.
    #
    # @param [String] command
    #   The name of the command to look for.
    #
    # @return [Boolean]
    #   True if the command is found in the path.
    #
    def command_in_path?(command)
      found = ENV['PATH'].split(File::PATH_SEPARATOR).map do |p|
        File.exist?(File.join(p, command))
      end
      found.include?(true)
    end

    # Looks for the first occurrence of program within path.
    #
    # @param [String] cmd
    #   The name of the command to find.
    #
    # @param [String] path
    #   The path to search for the command.
    #
    # @return [String, NilClass]
    #
    # @api public
    def which(prog, path = ENV['PATH'])
      path.split(File::PATH_SEPARATOR).each do |dir|
        file = File.join(dir, prog)
        return file if File.executable?(file) && !File.directory?(file)
      end

      nil
    end

    # In block form, yields each program within path. In non-block form,
    # returns an array of each program within path. Returns nil if not found
    # found.
    #
    # @example
    #   whereis('ruby')
    #     # => [
    #         [0] "/opt/chefdk/embedded/bin/ruby",
    #         [1] "/usr/bin/ruby",
    #         [2] "/Users/sharding/.rvm/rubies/ruby-2.2.0/bin/ruby",
    #         [3] "/usr/bin/ruby"
    #     ]
    #
    # @param [String] cmd
    #   The name of the command to find.
    #
    # @param [String] path
    #   The path to search for the command.
    #
    # @return [String, Array, NilClass]
    #
    # @api public
    def whereis(prog, path = ENV['PATH'])
      dirs = []
      path.split(File::PATH_SEPARATOR).each do |dir|
        f = File.join(dir,prog)
        if File.executable?(f) && !File.directory?(f)
          if block_given?
            yield f
          else
            dirs << f
          end
        end
      end

      dirs.empty? ? nil : dirs
    end

    # Get a recusive list of files inside a path.
    #
    # @param [String] path
    #   some path string or Pathname
    # @param [Block] ignore
    #   a proc/block that returns true if a given path should be ignored, if a
    #   path is ignored, nothing below it will be searched either.
    #
    # @return [Array<Pathname>]
    #   array of Pathnames for each file (no directories)
    #
    def all_files_under(path, &ignore)
      path = Pathname(path)

      if path.directory?
        path.children.flat_map do |child|
          all_files_under(child, &ignore)
        end.compact
      elsif path.file?
        if block_given? && ignore.call(path)
          []
        else
          [path]
        end
      else
        []
      end
    end

    # Takes an object, which can be a literal string or a string containing
    # glob expressions, or a regexp, or a proc, or anything else that responds
    # to #match or #call, and returns whether or not the given path matches
    # that matcher.
    #
    # @param [String, #match, #call] matcher
    #   a matcher String, RegExp, Proc, etc.
    #
    # @param [String] path
    #   a path as a string
    #
    # @return [Boolean]
    #   whether the path matches the matcher
    #
    def path_match(matcher, path)
      case
      when matcher.is_a?(String)
        if matcher.include? '*'
          File.fnmatch(matcher, path)
        else
          path == matcher
        end
      when matcher.respond_to?(:match)
        !matcher.match(path).nil?
      when matcher.respond_to?(:call)
        matcher.call(path)
      else
        File.fnmatch(matcher.to_s, path)
      end
    end

    # Normalize a path to not include a leading slash
    #
    # @param [String] path
    #
    # @return [String]
    #
    def normalize_path(path)
      path.sub(%r{^/}, '').tr('', '')
    end

    # Same as `File.open`, but acts on a temporary copy of named
    # file, copying the file back to the original on completion.
    #
    # @uncommon
    #   require 'facets/fileutils/atomic_open'
    #
    def self.atomic_open(file_name, mode='r', temp_dir = nil, &block)
      temp_dir  = temp_dir || Dir.tmpdir
      temp_file = Tempfile.new("#{aomtic_id}-" + basename(file_name), temp_dir)
      FileUtils.cp(file_name, temp_file) if File.exist?(file_name)
      open(temp_file, mode, &block)
      FileUtils.cp(temp_file, file_name)
    end

    # Write to a file atomically. Useful for situations where you don't
    # want other processes or threads to see half-written files.
    #
    #   File.atomic_write("important.txt") do |file|
    #     file.write("hello")
    #   end
    #
    # If your temporary directory is not on the same filesystem as the file
    # you're trying to write, you can provide a different temporary directory.
    #
    #   File.atomic_write("important.txt", "tmp") do |file|
    #     file.write("hello")
    #   end
    #
    def self.atomic_write(file_name, temp_dir = nil)
      temp_dir  = temp_dir || Dir.tmpdir
      temp_file = Tempfile.new(basename(file_name), temp_dir)

      yield temp_file
      temp_file.close

      begin
        old_stat = stat(file_name)
      rescue Errno::ENOENT
        check_name = join(dirname(file_name), ".permissions_check.#{Thread.current.object_id}.#{Process.pid}.#{rand(1000000)}")
        open(check_name, "w") { }
        old_stat = stat(check_name)
        unlink(check_name)
      end

      FileUtils.mv(temp_file.path, file_name)

      chown(old_stat.uid, old_stat.gid, file_name)
      chmod(old_stat.mode, file_name)
    end

    # Reads in a file, removes blank lines and removes lines starting
    # with '#' and then returns an array of all the remaining lines.
    #
    # Thr remark indicator can be overridden via the +:omit:+ option, which
    # can be a regualar expression or a string that is match against the
    # start of a line.
    #
    def self.read_list(filepath, options={})
      chomp = options[:chomp]
      omit  = case options[:omit]
              when Regexp
                omit
              when nil
                /^\s*\#/
              else
                /^\s*#{Regexp.escape(omit)}/
              end

      list = []
      readlines(filepath).each do |line|
        line = line.strip.chomp(chomp)
        next if line.empty?
        next if omit === line
        list << line
      end
      list
    end
  end
end
