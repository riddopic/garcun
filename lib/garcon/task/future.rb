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

require_relative 'ivar'
require_relative 'safe_task_executor'
require_relative 'executor_options'

module Garcon

  class Future < IVar
    include ExecutorOptions

    # Create a new `Future` in the `:unscheduled` state.
    #
    # @yield the asynchronous operation to perform
    #
    # @!macro executor_and_deref_options
    #
    # @option opts [object, Array] :args
    #  Zero or more arguments to be passed the task block on execution.
    #
    # @raise [ArgumentError] if no block is given
    #
    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?
      super(IVar::NO_VALUE, opts)
      @state    = :unscheduled
      @task     = block
      @executor = get_executor_from(opts) || Garcon.global_io_executor
      @args     = get_arguments_from(opts)
    end

    # Execute an `:unscheduled` `Future`. Immediately sets the state to
    # `:pending` and passes the block to a new thread/thread pool for eventual
    # execution. Does nothing if the `Future` is in any state other than
    # `:unscheduled`.
    #
    # @return [Future] a reference to `self`
    #
    # @example Instance and execute in separate steps
    #   future = Garcon::Future.new{ sleep(1); 42 }
    #   future.state #=> :unscheduled
    #   future.execute
    #   future.state #=> :pending
    #
    # @example Instance and execute in one line
    #   future = Garcon::Future.new{ sleep(1); 42 }.execute
    #   future.state #=> :pending
    def execute
      if compare_and_set_state(:pending, :unscheduled)
        @executor.post(@args){ work }
        self
      end
    end

    # Create a new `Future` object with the given block, execute it, and return
    # the `:pending` object.
    #
    # @example
    #   future = Garcon::Future.execute{ sleep(1); 42 }
    #   future.state #=> :pending
    #
    # @yield the asynchronous operation to perform.
    #
    # @!macro executor_and_deref_options.
    #
    # @option opts [object, Array] :args
    #   Zero or more arguments to be passed the task block on execution.
    #
    # @raise [ArgumentError] if no block is given.
    #
    # @return [Future]
    #   The newly created `Future` in the `:pending` state.
    #
    def self.execute(opts = {}, &block)
      Future.new(opts, &block).execute
    end

    protected :set, :fail, :complete

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    # @!visibility private
    def work
      success, val, reason = SafeTaskExecutor.new(@task).execute(*@args)
      complete(success, val, reason)
    end
  end
end
