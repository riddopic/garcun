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

require_relative 'atomic'

module Garcon

  # read-write Lock for cooking safety.
  #
  # Allows any number of concurrent readers, but only one concurrent writer
  # (And if the "write" lock is taken, any readers who come along will have to
  # wait). If readers are already active when a writer comes along, the writer
  # will wait for all the readers to finish before going ahead. Any additional
  # readers that come when the writer is already waiting, will also wait (so
  # writers are not starved).
  #
  # @example
  #   lock = Garcon::ReadWriteLock.new
  #   lock.with_read_lock  { data.retrieve }
  #   lock.with_write_lock { data.modify! }
  #
  # @note
  #   Do **not** try to acquire the write lock while already holding a read lock
  #   **or** try to acquire the write lock while you already have it.
  #   This will lead to deadlock
  #
  class ReadWriteLock

    # @!visibility private
    WAITING_WRITER  = 1 << 15

    # @!visibility private
    RUNNING_WRITER  = 1 << 30

    # @!visibility private
    MAX_READERS     = WAITING_WRITER - 1

    # @!visibility private
    MAX_WRITERS     = RUNNING_WRITER - MAX_READERS - 1

    # Implementation notes:
    # * A goal is to make the uncontended path for both readers/writers
    #   lock-free.
    # * Only if there is reader-writer or writer-writer contention, should
    #   locks be used.
    # * Internal state is represented by a single integer ("counter"), and
    #   updated using atomic compare-and-swap operations.
    # * When the counter is 0, the lock is free.
    # * Each reader increments the counter by 1 when acquiring a read lock (and
    #   decrements by 1 when releasing the read lock).
    # * The counter is increased by (1 << 15) for each writer waiting to
    #   acquire the write lock, and by (1 << 30) if the write lock is taken.

    # Create a new `ReadWriteLock` in the unlocked state.
    #
    def initialize
      @counter      = AtomicMutex.new(0)    # represents lock state
      @reader_q     = ConditionVariable.new # queue for waiting readers
      @reader_mutex = Mutex.new             # to protect reader queue
      @writer_q     = ConditionVariable.new # queue for waiting writers
      @writer_mutex = Mutex.new             # to protect writer queue
    end

    # Execute a block operation within a read lock.
    #
    # @return [Object]
    #   The result of the block operation.
    #
    # @yield the task to be performed within the lock.
    #
    # @raise [ArgumentError]
    #   When no block is given.
    #
    # @raise [Garcon::ResourceLimitError]
    #   If the maximum number of readers is exceeded.
    #
    def with_read_lock
      raise ArgumentError, 'no block given' unless block_given?
      acquire_read_lock
      begin
        yield
      ensure
        release_read_lock
      end
    end

    # Execute a block operation within a write lock.
    #
    # @return [Object] the result of the block operation.
    #
    # @yield the task to be performed within the lock.
    #
    # @raise [ArgumentError]
    #   When no block is given.
    #
    # @raise [Garcon::ResourceLimitError]
    #   If the maximum number of readers is exceeded.
    #
    def with_write_lock
      raise ArgumentError, 'no block given' unless block_given?
      acquire_write_lock
      begin
        yield
      ensure
        release_write_lock
      end
    end

    # Acquire a read lock. If a write lock has been acquired will block until
    # it is released. Will not block if other read locks have been acquired.
    #
    # @return [Boolean]
    #   True if the lock is successfully acquired.
    #
    # @raise [Garcon::ResourceLimitError]
    #   If the maximum number of readers is exceeded.
    #
    def acquire_read_lock
      while(true)
        c = @counter.value
        raise ResourceLimitError, 'Too many reader threads' if max_readers?(c)

        if waiting_writer?(c)
          @reader_mutex.synchronize do
            @reader_q.wait(@reader_mutex) if waiting_writer?
          end

          while(true)
            c = @counter.value
            if running_writer?(c)
              @reader_mutex.synchronize do
                @reader_q.wait(@reader_mutex) if running_writer?
              end
            else
              return if @counter.compare_and_swap(c,c+1)
            end
          end
        else
          break if @counter.compare_and_swap(c,c+1)
        end
      end
      true
    end

    # Release a previously acquired read lock.
    #
    # @return [Boolean]
    #   True if the lock is successfully released.
    #
    def release_read_lock
      while(true)
        c = @counter.value
        if @counter.compare_and_swap(c,c-1)
          if waiting_writer?(c) && running_readers(c) == 1
            @writer_mutex.synchronize { @writer_q.signal }
          end
          break
        end
      end
      true
    end

    # Acquire a write lock. Will block and wait for all active readers and
    # writers.
    #
    # @return [Boolean]
    #   True if the lock is successfully acquired.
    #
    # @raise [Garcon::ResourceLimitError]
    #   If the maximum number of writers is exceeded.
    #
    def acquire_write_lock
      while(true)
        c = @counter.value
        raise ResourceLimitError, 'Too many writer threads' if max_writers?(c)

        if c == 0
          break if @counter.compare_and_swap(0,RUNNING_WRITER)
        elsif @counter.compare_and_swap(c,c+WAITING_WRITER)
          while(true)
            @writer_mutex.synchronize do
              c = @counter.value
              if running_writer?(c) || running_readers?(c)
                @writer_q.wait(@writer_mutex)
              end
            end

            c = @counter.value
            break if !running_writer?(c) && !running_readers?(c) &&
              @counter.compare_and_swap(c,c+RUNNING_WRITER-WAITING_WRITER)
          end
          break
        end
      end
      true
    end

    # Release a previously acquired write lock.
    #
    # @return [Boolean]
    #   True if the lock is successfully released.
    #
    def release_write_lock
      while(true)
        c = @counter.value
        if @counter.compare_and_swap(c,c-RUNNING_WRITER)
          @reader_mutex.synchronize { @reader_q.broadcast }
          if waiting_writers(c) > 0
            @writer_mutex.synchronize { @writer_q.signal }
          end
          break
        end
      end
      true
    end

    # Returns a string representing *obj*. Includes the current reader and
    # writer counts.
    #
    def to_s
      c = @counter.value
      s = if running_writer?(c)
            "1 writer running, "
          elsif running_readers(c) > 0
            "#{running_readers(c)} readers running, "
          else
            ""
          end

      "#<ReadWriteLock:#{object_id.to_s(16)} #{s}#{waiting_writers(c)} writers waiting>"
    end

    # Queries if the write lock is held by any thread.
    #
    # @return [Boolean]
    #   True if the write lock is held else false.
    #
    def write_locked?
      @counter.value >= RUNNING_WRITER
    end

    # Queries whether any threads are waiting to acquire the read or write lock.
    #
    # @return [Boolean]
    #   True if any threads are waiting for a lock else false.
    #
    def has_waiters?
      waiting_writer?(@counter.value)
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    # @!visibility private
    def running_readers(c = @counter.value)
      c & MAX_READERS
    end

    # @!visibility private
    def running_readers?(c = @counter.value)
      (c & MAX_READERS) > 0
    end

    # @!visibility private
    def running_writer?(c = @counter.value)
      c >= RUNNING_WRITER
    end

    # @!visibility private
    def waiting_writers(c = @counter.value)
      (c & MAX_WRITERS) / WAITING_WRITER
    end

    # @!visibility private
    def waiting_writer?(c = @counter.value)
      c >= WAITING_WRITER
    end

    # @!visibility private
    def max_readers?(c = @counter.value)
      (c & MAX_READERS) == MAX_READERS
    end

    # @!visibility private
    def max_writers?(c = @counter.value)
      (c & MAX_WRITERS) == MAX_WRITERS
    end
  end
end
