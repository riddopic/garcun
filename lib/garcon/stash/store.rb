# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014-2015 Stefano Harding
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

#     _____ ______   ____  _____ __ __         __   ____    __  __ __    ___
#    / ___/|      T /    T/ ___/|  T  T       /  ] /    T  /  ]|  T  T  /  _]
#   (   \_ |      |Y  o  (   \_ |  l  |      /  / Y  o  | /  / |  l  | /  [_
#    \__  Tl_j  l_j|     |\__  T|  _  |     /  /  |     |/  /  |  _  |Y    _]
#    /  \ |  |  |  |  _  |/  \ ||  |  |    /   \_ |  _  /   \_ |  |  ||   [_
#    \    |  |  |  |  |  |\    ||  |  |    \     ||  |  \     ||  |  ||     T
#     \___j  l__j  l__j__j \___jl__j__j     \____jl__j__j\____jl__j__jl_____j
#
#           __ __   ____  _____ __ __       _____ ______   ___   ____     ___
#          |  T  T /    T/ ___/|  T  T     / ___/|      T /   \ |    \   /  _]
#          |  l  |Y  o  (   \_ |  l  |    (   \_ |      |Y     Y|  D  ) /  [_
#          |  _  ||     |\__  T|  _  |     \__  Tl_j  l_j|  O  ||    / Y    _]
#          |  |  ||  _  |/  \ ||  |  |     /  \ |  |  |  |     ||    \ |   [_
#          |  |  ||  |  |\    ||  |  |     \    |  |  |  l     !|  .  Y|     T
#          l__j__jl__j__j \___jl__j__j      \___j  l__j   \___/ l__j\_jl_____j
#

require 'thread'
require 'zlib'
require_relative 'serializer'
require_relative 'format'
require_relative 'queue'
require_relative 'journal'

module Garcon
  module Stash
    # Stash::Store contains the public api for Stash. It includes
    # Enumerable for functional goodies like map, each, reduce and friends.
    #
    # @api public
    class Store
      include Enumerable

      # Set default value, can be a callable
      attr_writer :default

      # Create a new Stash::Store. The second argument is the default value
      # to store when accessing a previously unset key, this follows the
      # Hash standard.
      #
      # @param [String] file
      #   The path to the Stash Store file.
      #
      # @param [Hash] opts
      #   Options hash for creating a new stash.
      #
      # @option opts [Class] :serializer
      #   Serializer class
      #
      # @option opts [Class] :format
      #   Format class
      #
      # @option opts [Object] :default
      #   Default value
      #
      # @yield [key] a block that will return the default value to store.
      #
      # @yieldparam [String] key the key to be stored.
      #
      def initialize(file, opts = {}, &block)
        opts = {
          serializer: opts.fetch(:serializer, Serializer::Default),
          format:     opts.fetch(:format,     Format),
          default:    opts.fetch(:default,    nil)
        }
        @format     = (opts[:format]).new
        @serializer = (opts[:serializer]).new
        @table      = Hash.new(&method(:hash_default))
        @journal    = Journal.new(file, @format, @serializer) do |record|
                        if !record
                          @table.clear
                        elsif record.size == 1
                          @table.delete(record.first)
                        else
                          @table[record.first] = @serializer.load(record.last)
                        end
                      end

        @default = block ? block : opts[:default]
        @mutex   = Mutex.new
        @@stashs_mutex.synchronize { @@stashs << self }
      end

      # Stash store file name.
      #
      # @return [String]
      #   stash store file name
      #
      def file
        @journal.file
      end

      # Return default value belonging to key.
      #
      # @param [Object] key
      #   the default value to retrieve.
      #
      # @return [Object]
      #   value the default value
      #
      def default(key = nil)
        @table.default(@serializer.key_for(key))
      end

      # Retrieve a value at key from the stash. If the default value was
      # specified when this stash was created, that value will be set and
      # returned. Aliased as `#get`.
      #
      # @param [Object] key
      #   the value to retrieve from the stash
      #
      # @return [Object]
      #   the value
      #
      def [](key)
        @table[@serializer.key_for(key)]
      end
      alias_method :get, '[]'

      # Set a key in the stash to be written at some future date. If the data
      # needs to be persisted immediately, call `#store.set(key, value, true)`.
      #
      # @param [Object] key
      #   the key of the storage slot in the stash
      #
      # @param [Object] value
      #   the value to store
      #
      # @return [Object]
      #   the value
      #
      def []=(key, value)
        key = @serializer.key_for(key)
        @journal << [key, value]
        @table[key] = value
      end
      alias_method :set, '[]='

      # Flushes data immediately to disk.
      #
      # @param [Object] key
      #   the key of the storage slot in the stash
      #
      # @param [Object] value
      #   the value to store
      #
      # @return [Object]
      #   the value
      #
      def set!(key, value)
        set(key, value)
        flush
        value
      end

      # Delete a key from the stash.
      #
      # @param [Object] key
      #   the key of the storage slot in the stash
      #
      # @return [Object]
      #   the value
      #
      def delete(key)
        key = @serializer.key_for(key)
        @journal << [key]
        @table.delete(key)
      end

      # Immediately delete the key on disk.
      #
      # @param [Object] key
      #   the key of the storage slot in the stash
      #
      # @return [Object]
      #   the value
      #
      def delete!(key)
        value = delete(key)
        flush
        value
      end

      # Update stash with hash (fast batch update).
      #
      # @param [Hash] hash
      #   the key/value hash
      #
      # @return [Stash] self
      #
      def update(hash)
        shash = {}
        hash.each { |key, value| shash[@serializer.key_for(key)] = value }
        @journal << shash
        @table.update(shash)
        self
      end

      # Updata stash and flush data to disk.
      #
      # @param [Hash] hash
      #   the key/value hash
      #
      # @return [Stash] self
      #
      def update!(hash)
        update(hash)
        @journal.flush
      end

      # Does this stash have this key?
      #
      #
      # @param [Object] key
      #   the key to check if the stash has it
      #
      # @return [Boolean]
      #
      def has_key?(key)
        @table.has_key?(@serializer.key_for(key))
      end
      alias_method :key?, :has_key?
      alias_method :include?, :has_key?
      alias_method :member?, :has_key?

      # Does this stash have this value?
      #
      # @param [Object] value
      #   the value to check if the Stash has it
      #
      # @return [Boolean]
      #
      def has_value?(value)
        @table.has_value?(value)
      end
      alias_method :value?, :has_value?

      # Return the number of stored items.
      #
      # @return [Fixnum]
      #
      def size
        @table.size
      end
      alias_method :length, :size

      # Utility method that will return the size of the stash in bytes, useful
      # for determining when to compact.
      #
      # @return [Fixnum]
      #
      def bytesize
        @journal.bytesize
      end

      # Counter of how many records are in the journal.
      #
      # @return [Fixnum]
      #
      def logsize
        @journal.size
      end

      # Return true if stash is empty.
      #
      # @return [Boolean]
      #
      def empty?
        @table.empty?
      end

      # Iterate over the key, value pairs in the stash.
      #
      # @yield [key, value] block
      #   the iterator for each key value pair
      #
      # @yieldparam key the key.
      #
      # @yieldparam value the value from the stash.
      #
      def each(&block)
        @table.each(&block)
      end

      # Return the keys in the stash.
      #
      # @return [Array<String>]
      #
      def keys
        @table.keys
      end

      # Flush all changes to disk.
      #
      # @return [Stash] self
      #
      def flush
        @journal.flush
        self
      end

      # Sync the stash with what is on disk, by first flushing changes, and then
      # loading the new records if necessary.
      #
      # @return [Stash] self
      #
      def load
        @journal.load
        self
      end
      alias_method :sunrise, :load

      # Lock the stash for an exclusive commit across processes and threads.
      # @note This method performs an expensive locking over process boundaries.
      # If you want to synchronize only between threads, use `#synchronize`.
      # @see #synchronize
      #
      # @yield a block where every change to the stash is synced
      # @yieldparam [Stash] stash
      # @return result of the block
      #
      def lock
        synchronize { @journal.lock { yield self } }
      end

      # Synchronize access to the stash from multiple threads.
      # @note Stash is not thread safe, if you want to access it from multiple
      # threads, all accesses have to be in the #synchronize block.
      # @see #lock
      #
      # @yield a block where every change to the stash is synced
      #
      # @yieldparam [Stash] stash
      #
      # @return result of the block
      #
      def synchronize
        @mutex.synchronize { yield self }
      end

      # Remove all keys and values from the stash.
      #
      # @return [Stash] self
      #
      def clear
        @table.clear
        @journal.clear
        self
      end

      # Compact the stash to remove stale commits and reduce the file size.
      #
      # @return [Stash] self
      #
      def compact
        @journal.compact { @table }
        self
      end

      # Close the stash for reading and writing.
      #
      # @return nil
      #
      def close
        @journal.close
        @@stashs_mutex.synchronize { @@stashs.delete(self) }
        nil
      end

      # Check to see if we've already closed the stash.
      #
      # @return [Boolean]
      #
      def closed?
        @journal.closed?
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      # @private
      @@stashs = []

      # @private
      @@stashs_mutex = Mutex.new

      # A handler that will ensure that stashs are closed and synced when the
      # current process exits.
      #
      # @private
      def self.exit_handler
        loop do
          stash = @@stashs_mutex.synchronize { @@stashs.shift }
          break unless stash
          warn "Stash #{stash.file} was not closed, state might be inconsistent"
          begin
            stash.close
          rescue Exception => e
            warn "Failed to close stash store: #{e.message}"
          end
        end
      end

      at_exit { Garcon::Stash::Store.exit_handler }

      # The block used in @table for new records.
      #
      def hash_default(_, key)
        if @default != nil
          value = @default.respond_to?(:call) ? @default.call(key) : @default
          @journal << [key, value]
          @table[key] = value
        end
      end
    end
  end
end
