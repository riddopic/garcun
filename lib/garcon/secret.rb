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

#     ______  __ __    ___       _____   ___     __  ____     ___  ______
#    |      T|  T  T  /  _]     / ___/  /  _]   /  ]|    \   /  _]|      T
#    |      ||  l  | /  [_     (   \_  /  [_   /  / |  D  ) /  [_ |      |
#    l_j  l_j|  _  |Y    _]     \__  TY    _] /  /  |    / Y    _]l_j  l_j
#      |  |  |  |  ||   [_      /  \ ||   [_ /   \_ |    \ |   [_   |  |
#      |  |  |  |  ||     T     \    ||     T\     ||  .  Y|     T  |  |
#      l__j  l__j__jl_____j      \___jl_____j \____jl__j\_jl_____j  l__j
#
#     __  _    ___    ___  ____    ___  ____   __
#    |  l/ ]  /  _]  /  _]|    \  /  _]|    \ |  T
#    |  ' /  /  [_  /  [_ |  o  )/  [_ |  D  )|  |
#    |    \ Y    _]Y    _]|   _/Y    _]|    / |__j
#    |     Y|   [_ |   [_ |  |  |   [_ |    \  __
#    |  .  ||     T|     T|  |  |     T|  .  Y|  T
#    l__j\_jl_____jl_____jl__j  l_____jl__j\_jl__j

require 'tempfile'
require 'fileutils'
require_relative 'utility/crypto'
require_relative 'utility/memstash'

module Garcon
  # Creates a transient file with sensitive content, usefule when you have an
  # excecutable that reads a password from a file but you do not wish to leave
  # the password on the filesystem. When used in a block parameter the file is
  # written and deleted when the block returns, optionally you can encrypt and
  # decrypt your secret strings with salt, cipher and a splash of obfuscation.
  #
  module Secret
    # A Configuration instance
    class Configuration

      # @!attribute [r] :lock
      #   @return [String] Access the shared Monitor for this instance.
      attr_reader :lock

      # @!attribute [rw] :stash
      #   @return [String] The shared Stash (in-memory cache) for this instance.
      attr_accessor :stash

      # @!attribute [rw] :queue
      #   @return [String] The shared queue object for this instance.
      attr_accessor :queue

      # Initialized a configuration instance
      #
      # @return [undefined]
      #
      # @api private
      def initialize(options = {})
        @lock   = Monitor.new
        @stash  = MemStash.new
        @queue  = MutexPriorityQueue.new
        @queue << Secret.tmpfile until @queue.length >= 4

        yield self if block_given?
      end

      # @api private
      def to_h
        { lock:  lock,
          stash: stash,
          queue: queue
        }.freeze
      end
    end

    # Encrypt and store the given value with the given key, either with an an
    # argument or block. If a previous value was set it will be overwritten
    # with the new value.
    #
    # @param key [Symbol, String]
    #   String or symbol representing the key.
    #
    # @param value [Object]
    #   Any object that represents the value.
    #
    # @yield [Block]
    #   Optionally specify a block that returns the value to set.
    #
    # @return [String]
    #   The encrypted value.
    #
    def self.set(key, value)
      Garcon.secret.stash[key] = value.encrypt
    end

    # Retrieve and decrypt a value at key from the stash.
    #
    # @param key [Symbol, String]
    #   String or symbol representing the key.
    #
    # @raise [KeyError]
    #   If no such key found.
    #
    # @return [String]
    #   Unencrypted value.
    #
    def self.get(key)
      (Garcon.secret.stash[key]).decrypt
    end

    # Creates the secrets file yields to the block, removes the secrets file
    # when the block returns
    #
    # @example
    #   secret.tmp { |file| shell_out!("open_sesame --passwd-file #{file}") }
    #
    # @yield [Block]
    #   invokes the block
    #
    # @yieldreturn [Object]
    #   the result of evaluating the optional block
    #
    # @api public
    def self.tmp(key, *args, &block)
      Garcon.secret.lock.synchronize do
        begin
          file = queue.pop
          atomic_write(file, get(key)) unless valid?(key, file)
          yield file if block_given?
        ensure
          File.unlink(file) if File.exist?(file)
        end
      end
    end

    # Search a text file for a matching string
    #
    # @return [Boolean]
    #   True if the file is present and a match was found, otherwise returns
    #   false if file does not exist and/or does not contain a match
    #
    # @api public
    def self.valid?(key, file)
      Garcon.secret.lock.synchronize do
        return false unless File.exist?(file)
        File.open(file, &:readlines).map! do |line|
          return true if line.match(get(key))
        end
        false
      end
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    def self.queue
      until Garcon.secret.queue.length >= 2
        Garcon.secret.queue << Secret.tmpfile
      end
      Garcon.secret.queue
    end

    # Write the secrets file
    #
    # @return [String]
    #   the path to the file
    #
    # @api private
    def self.write(key, file)
      Garcon.secret.lock.synchronize do
        begin
          atomic_write(file, get(key)) unless valid?(key, file)
        ensure
          File.chmod(00400, file)
        end
      end
    end

    # Delete the secrets file
    #
    # @return [undefined]
    #
    # @api private
    def self.delete(file = nil)
      Garcon.secret.lock.synchronize do
        if file.nil?
          until Garcon.secret.queue.length == 0
            tmpfile = Garcon.secret.queue.pop
            File.unlink(tmpfile) if File.exist?(tmpfile)
          end
        else
          File.unlink(file) if File.exist?(file)
        end
      end
    end

    # Write to a file atomically. Useful for situations where you don't
    # want other processes or threads to see half-written files.
    #
    # @param [String] file
    #   fill path of the file to write to
    # @param [String] secret
    #   content to write to file
    #
    # @api private
    def self.atomic_write(file, secret, tmp_dir = Dir.tmpdir)
      tmp_file = Tempfile.new(File.basename(file), tmp_dir)
      tmp_file.write(secret)
      tmp_file.close

      FileUtils.mv(tmp_file.path, file)
      begin
        File.chmod(00400, file)
      rescue Errno::EPERM, Errno::EACCES
        # Changing file ownership/permissions failed
      end
    ensure
      tmp_file.close
      tmp_file.unlink
    end

    # Lock a file for a block so only one process can modify it at a time
    #
    # @param [String] file
    #   fill path of the file to lock
    #
    # @yield [Block]
    #   invokes the block
    #
    # @yieldreturn [Object]
    #   the result of evaluating the optional block
    #
    # @api private
    def self.lock_file(file, &block)
      if File.exist?(file)
        File.open(file, 'r+') do |f|
          begin
            f.flock File::LOCK_EX
            yield
          ensure
            f.flock File::LOCK_UN
          end
        end
      else
        yield
      end
    end

    # @return [String] tmp_file
    # @api private
    def self.tmpfile(tmp_dir = Dir.tmpdir)
      Tempfile.new(random_seed, tmp_dir).path.freeze
    end

    # @return [String] random_seed
    # @api private
    def self.random_seed
      SecureRandom.random_number(0x100000000).to_s(36)
    end
  end
end
