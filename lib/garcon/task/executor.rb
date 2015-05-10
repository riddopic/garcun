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

require_relative 'event'

module Garcon

  module Executor
    # The policy defining how rejected tasks (tasks received once the queue size
    # reaches the configured `max_queue`, or after the executor has shut down)
    # are handled. Must be one of the values specified in `FALLBACK_POLICY`.
    attr_reader :fallback_policy

    # Does the task queue have a maximum size?
    #
    # @note Always returns `false`
    #
    # @return [Boolean] True if the task queue has a maximum size else false.
    #
    # @note Always returns `false`
    def can_overflow?
      false
    end

    # Handler which executes the `fallback_policy` once the queue size reaches
    # `max_queue`.
    #
    # @param [Array] args
    #   The arguments to the task which is being handled.
    #
    # @!visibility private
    def handle_fallback(*args)
      case @fallback_policy
      when :abort
        raise RejectedExecutionError
      when :discard
        false
      when :caller_runs
        begin
          yield(*args)
        rescue => e
          Chef::Log.debug "Caught exception => #{e}"
        end
        true
      else
        fail "Unknown fallback policy #{@fallback_policy}"
      end
    end

    # Does this executor guarantee serialization of its operations?
    #
    # @note
    #   Always returns `false`
    #
    # @return [Boolean]
    #   True if the executor guarantees that all operations will be post in the
    #   order they are received and no two operations may occur simultaneously.
    #   Else false.
    def serialized?
      false
    end

    def auto_terminate?
      !! @auto_terminate
    end

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    def enable_at_exit_handler!(opts = {})
      if opts.fetch(:stop_on_exit, true)
        @auto_terminate = true
        create_mri_at_exit_handler!(self.object_id)
      end
    end

    def create_mri_at_exit_handler!(id)
      at_exit do
        if Garcon.auto_terminate_all_executors?
          this = ObjectSpace._id2ref(id)
          this.kill if this
        end
      end
    end

    def create_at_exit_handler!(this)
      at_exit do
        this.kill if Garcon.auto_terminate_all_executors?
      end
    end
  end

  # Indicates that the including `Executor` or `ExecutorService` guarantees
  # that all operations will occur in the order they are post and that no
  # two operations may occur simultaneously. This module provides no
  # functionality and provides no guarantees. That is the responsibility
  # of the including class. This module exists solely to allow the including
  # object to be interrogated for its serialization status.
  #
  # @example
  #   class Foo
  #     include Garcon::SerialExecutor
  #   end
  #
  #   foo = Foo.new
  #
  #   foo.is_a? Garcon::Executor       # => true
  #   foo.is_a? Garcon::SerialExecutor # => true
  #   foo.serialized?                  # => true
  module SerialExecutor
    include Executor

    # @note
    #   Always returns `true`
    def serialized?
      true
    end
  end

  module RubyExecutor
    include Executor

    # The set of possible fallback policies that may be set at thread pool
    # creation.
    FALLBACK_POLICY = [:abort, :discard, :caller_runs]

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Array] args
    #   Zero or more arguments to be passed to the task
    #
    # @yield the asynchronous task to perform
    #
    # @raise [ArgumentError]
    #   if no task is given
    #
    # @return [Boolean]
    #   True if the task is queued, false if the executor is not running.
    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      mutex.synchronize do
        # If the executor is shut down, reject this task
        return handle_fallback(*args, &task) unless running?
        execute(*args, &task)
        true
      end
    end

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Proc] task
    #   the asynchronous task to perform
    #
    # @return [self]
    #   returns itself
    def <<(task)
      post(&task)
      self
    end

    # Is the executor running?
    #
    # @return [Boolean]
    #   True when running, false when shutting down or shutdown.
    def running?
      ! stop_event.set?
    end

    # Is the executor shuttingdown?
    #
    # @return [Boolean]
    #   True when not running and not shutdown, else false.
    def shuttingdown?
      ! (running? || shutdown?)
    end

    # Is the executor shutdown?
    #
    # @return [Boolean]
    #   True when shutdown, false when shutting down or running.
    def shutdown?
      stopped_event.set?
    end

    # Begin an orderly shutdown. Tasks already in the queue will be executed,
    # but no new tasks will be accepted. Has no additional effect if the
    # thread pool is not running.
    #
    def shutdown
      mutex.synchronize do
        break unless running?
        stop_event.set
        shutdown_execution
      end
      true
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to complete
    # but enqueued tasks will be dismissed and no new tasks will be accepted.
    # Has no additional effect if the thread pool is not running.
    #
    def kill
      mutex.synchronize do
        break if shutdown?
        stop_event.set
        kill_execution
        stopped_event.set
      end
      true
    end

    # Block until executor shutdown is complete or until `timeout` seconds have
    # passed.
    #
    # @note
    #   Does not initiate shutdown or termination. Either shutdown or kill must
    #   be called before this method (or on another thread).
    #
    # @param [Integer] timeout
    #   The maximum number of seconds to wait for shutdown to complete
    #
    # @return [Boolean]
    #   True if shutdown complete or false on timeout.
    def wait_for_termination(timeout = nil)
      stopped_event.wait(timeout)
    end

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    attr_reader :mutex, :stop_event, :stopped_event

    # Initialize the executor by creating and initializing all the internal
    # synchronization objects.
    #
    def init_executor
      @mutex         = Mutex.new
      @stop_event    = Event.new
      @stopped_event = Event.new
    end

    def execute(*args, &task)
      raise NotImplementedError
    end

    # Callback method called when an orderly shutdown has completed. The default
    # behavior is to signal all waiting threads.
    #
    def shutdown_execution
      stopped_event.set
    end

    # Callback method called when the executor has been killed. The default
    # behavior is to do nothing.
    #
    def kill_execution
      # do nothing
    end
  end
end
