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

require 'thread'    unless defined?(Thread)
require 'tempfile'  unless defined?(Tempfile)
require 'fileutils' unless defined?(FileUtils)

class File

  def self.atomic_id
    @atomic_id ||= 0
    @atomic_id += 1
  end

  # Same as `File.open`, but acts on a temporary copy of named
  # file, copying the file back to the original on completion.
  #
  # @uncommon
  #   require 'facets/fileutils/atomic_open'
  #
  def self.atomic_open(file_name, mode="r", temp_dir=nil, &block)
    temp_dir  = temp_dir || Dir.tmpdir
    temp_file = Tempfile.new("#{aomtic_id}-" + basename(file_name), temp_dir)

    if File.exist?(file_name)
      FileUtils.cp(file_name, temp_file)
    end

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
  # If your temporary directory is not on the same filesystem as the file you're
  # trying to write, you can provide a different temporary directory.
  #
  #   File.atomic_write("important.txt", "tmp") do |file|
  #     file.write("hello")
  #   end
  #
  # NOTE: This method is not a common core extension and is not
  # loaded automatically when using <code>require 'facets'</code>.
  #
  # CREDIT: David Heinemeier Hansson
  #
  # @uncommon
  #   require 'facets/fileutils/atomic_write'
  #
  def self.atomic_write(file_name, temp_dir=nil)
    temp_dir  = temp_dir || Dir.tmpdir
    temp_file = Tempfile.new(basename(file_name), temp_dir)

    yield temp_file
    temp_file.close

    begin
      ## Get original file permissions
      old_stat = stat(file_name)
    rescue Errno::ENOENT
      ## No old permissions, write a temp file to determine the defaults
      check_name = join(dirname(file_name), ".permissions_check.#{Thread.current.object_id}.#{Process.pid}.#{rand(1000000)}")
      open(check_name, "w") { }
      old_stat = stat(check_name)
      unlink(check_name)
    end

    ## Overwrite original file with temp file
    FileUtils.mv(temp_file.path, file_name)

    ## Set correct permissions on new file
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
  # CREDIT: Trans

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
