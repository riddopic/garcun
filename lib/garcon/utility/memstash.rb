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

require_relative '../core_ext/method_access'

module Garcon
  # Hash that allows you to access keys of the hash via method calls This gives
  # you an OStruct like way to access your hash's keys. It will recognize keys
  # either as strings or symbols.
  #
  class StashCache < Hash
    include Garcon::Extensions::MethodAccess
    include Garcon::Extensions::PrettyInspect
  end

  # In-process cache with least-recently used (LRU) and time-to-live (TTL)
  # expiration semantics. This implementation is thread-safe. It does not use
  # a thread to clean up expired values. Instead, an expiration check is
  # performed:
  #
  # 1. Every time you retrieve a value, against that value. If the value has
  #    expired, it will be removed and `nil` will be returned.
  #
  # 2. Every `expire_interval` operations as the cache is used to remove all
  #    expired values up to that point.
  #
  # For manual expiration call {#expire!}.
  #
  class MemStash
    # The maximum number of seconds an element can exist in the cache
    # regardless of use. The element expires at this limit and will no longer
    # be returned from the cache. The default value is 3600, or 1 hour. Setting
    # A TTL value of 0 means no TTL eviction takes place (infinite lifetime).
    DEFAULT_TTL_SECONDS = 3600

    # The maximum number of seconds an element can exist in the cache without
    # being accessed. The element expires at this limit and will no longer be
    # returned from the cache. The default value is 3600, or 1 hour. Setting a
    # TTI value of 0 means no TTI eviction takes place (infinite lifetime).
    DEFAULT_TTI_SECONDS = 3600

    # The maximum sum total number of elements (cache entries) allowed on the
    # disk tier for the cache. If this target is exceeded, eviction occurs to
    # bring the count within the allowed target. The default value is 100. A
    # setting of 0 means that no eviction of the cache's entries takes place
    # (infinite size is allowed), and consequently can cause the node to run
    # out of disk space.
    DEFAULT_MAX_ENTRIES = 100

    # @!attribute [r] :stats
    #   @return [CacheStats] The Cache statistics.
    attr_reader :stats

    # @!attribute [r] :ttl (DEFAULT_TTL_SECONDS)
    #   @return [Integer] The time to live for an element before it expires.
    attr_reader :ttl

    # @!attribute [r] :tti (DEFAULT_TTI_SECONDS)
    #   @return [Integer] The time to idle for an element before it expires.
    attr_reader :tti

    # Initializes the cache.
    #
    # @param [Hash] opts
    #   The options to configure the cache.
    #
    # @option opts [Integer] :max_entries
    #   Maximum number of elements in the cache.
    #
    # @option opts [Numeric] :ttl
    #   Maximum time, in seconds, for a value to stay in the cache.
    #
    # @option opts [Numeric] :tti
    #   Maximum time, in seconds, for a value to stay in the cache without
    #   being accessed.
    #
    # @option opts [Integer] :interval
    #   Number of cache operations between calls to {#expire!}.
    #
    def initialize(opts = {})
      @max_entries = opts.fetch(:max_entries, DEFAULT_MAX_ENTRIES)
      @ttl_seconds = opts.fetch(:ttl_seconds, DEFAULT_TTL_SECONDS)
      @tti_seconds = opts.fetch(:ttl_seconds, DEFAULT_TTI_SECONDS)
      @interval    = opts.fetch(:interval, 100)
      @operations  = 0
      @monitor     = Monitor.new
      @stash       = {}
      @expires_at  = {}
    end

    # Loads a hash of data into the stash.
    #
    # @param [Hash] data
    #   Hash of data with either String or Symbol keys.
    #
    # @return nothing.
    #
    def load(data)
      @monitor.synchronize do
        data.each do |key, value|
          expire!
          store(key, val)
        end
      end
    end

    # Retrieves a value from the cache, if available and not expired, or yields
    # to a block that calculates the value to be stored in the cache.
    #
    # @param [Object] key
    #   The key to look up or store at.
    #
    # @yield yields when the value is not present.
    #
    # @yieldreturn [Object]
    #   The value to store in the cache.
    #
    # @return [Object]
    #   The value at the key.
    #
    def fetch(key)
      @monitor.synchronize do
        found, value = get(key)
        found ? value : store(key, yield)
      end
    end

    # Retrieves a value from the cache.
    #
    # @param [Object] key
    #   The key to look up.
    #
    # @return [Object, nil]
    #   The value at the key, when present, or `nil`.
    #
    def [](key)
      @monitor.synchronize do
        _, value = get(key)
        value
      end
    end
    alias_method :get, :[]

    # Stores a value in the cache.
    #
    # @param [Object] key
    #   The key to store.
    #
    # @param val [Object]
    #   The value to store.
    #
    # @return [Object, nil]
    #   The value at the key.
    #
    def []=(key, val)
      @monitor.synchronize do
        expire!
        store(key, val)
      end
    end
    alias_method :set, :[]=

    # Removes a value from the cache.
    #
    # @param [Object] key
    #   The key to remove.
    #
    # @return [Object, nil]
    #   The value at the key, when present, or `nil`.
    #
    def delete(key)
      @monitor.synchronize do
        entry = @stash.delete(key)
        if entry
          @expires_at.delete(entry)
          entry.value
        else
          nil
        end
      end
    end

    # Checks whether the cache is empty.
    #
    # @note calls to {#empty?} do not count against `expire_interval`.
    #
    # @return [Boolean]
    #
    def empty?
      @monitor.synchronize { count == 0 }
    end

    # Clears the cache.
    #
    # @return [self]
    #
    def clear
      @monitor.synchronize do
        @stash.clear
        @expires_at.clear
        self
      end
    end

    # Returns the number of elements in the cache.
    #
    # @note
    #   Calls to {#empty?} do not count against `expire_interval`. Therefore,
    #   the number of elements is that prior to any expiration.
    #
    # @return [Integer]
    #   Number of elements in the cache.
    #
    def count
      @monitor.synchronize { @stash.count }
    end
    alias_method :size,   :count
    alias_method :length, :count

    # Allows iteration over the items in the cache. Enumeration is stable: it
    # is not affected by changes to the cache, including value expiration.
    # Expired values are removed first.
    #
    # @note
    #   The returned values could have expired by the time the client code gets
    #   to accessing them.
    #
    # @note
    #   Because of its stability, this operation is very expensive. Use with
    #   caution.
    #
    # @yield [Array<key, value>]
    #   Key/value pairs, when a block is provided.
    #
    # @return [Enumerator, Array<key, value>]
    #   An Enumerator, when no block is provided, or array of key/value pairs.
    #
    def each(&block)
      @monitor.synchronize do
        expire!
        @stash.map { |key, entry| [key, entry.value] }.each(&block)
      end
    end

    # Removes expired values from the cache.
    #
    # @return [self]
    #
    def expire!
      @monitor.synchronize do
        check_expired(Time.now.to_f)
        self
      end
    end

    # Return all keys in the store as an array.
    #
    # @return [Array<String, Symbol>] all the keys in store
    #
    def keys
      @monitor.synchronize { @stash.keys }
    end

    # Returns information about the number of objects in the cache, its
    # maximum size and TTL.
    #
    # @return [String]
    #
    def inspect
      @monitor.synchronize do
        "<#{self.class.name} count=#{count} max_entries=#{@max_entries} " \
        "ttl=#{@ttl_seconds}>"
      end
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    # @private
    class Entry
      attr_reader :value
      attr_reader :expires_at

      def initialize(value, expires_at)
        @value = value
        @expires_at = expires_at
      end
    end

    def get(key)
      @monitor.synchronize do
        time = Time.now.to_f
        check_expired(time)
        found = true
        entry = @stash.delete(key) { found = false }
        if found
          if entry.expires_at <= time
            @expires_at.delete(entry)
            return false, nil
          else
            @stash[key] = entry
            return true, entry.value
          end
        else
          return false, nil
        end
      end
    end

    def store(key, val)
      @monitor.synchronize do
        expires_at = Time.now.to_f + @ttl_seconds
        entry = Entry.new(val, expires_at)
        store_entry(key, entry)
        val
      end
    end

    def store_entry(key, entry)
      @monitor.synchronize do
        @stash.delete(key)
        @stash[key] = entry
        @expires_at[entry] = key
        shrink_if_needed
      end
    end

    def shrink_if_needed
      @monitor.synchronize do
        if @stash.length > @max_entries
          entry = delete(@stash.shift)
          @expires_at.delete(entry)
        end
      end
    end

    def check_expired(time)
      @monitor.synchronize do
        if (@operations += 1) % @interval == 0
          while (key_value_pair = @expires_at.first) &&
              (entry = key_value_pair.first).expires_at <= time
            key = @expires_at.delete(entry)
            @stash.delete(key)
          end
        end
      end
    end
  end
end
