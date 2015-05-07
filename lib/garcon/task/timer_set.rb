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
require_relative 'event'
require_relative 'priority_queue'
require_relative 'executor'
require_relative 'single_thread_executor'
require_relative 'monotonic_time'
require_relative 'executor_options'

module Garcon

  # Executes a collection of tasks, each after a given delay. A master task
  # monitors the set and schedules each task for execution at the appropriate
  # time. Tasks are run on the global task pool or on the supplied executor.
  #
  class TimerSet
    include RubyExecutor
    include ExecutorOptions

    # Create a new set of timed tasks.
    #
    # @!macro [attach] executor_options
    #
    # @param [Hash] opts
    #   The options used to specify the executor on which to perform actions.
    #
    # @option opts [Executor] :executor
    #   When set use the given `Executor` instance. Three special values are
    #   also supported: `:task` returns the global task pool, `:operation`
    #   returns the global operation pool, and `:immediate` returns a new
    #  `ImmediateExecutor` object.
    #
    def initialize(opts = {})
      @queue          = PriorityQueue.new(order: :min)
      @task_executor  = get_executor_from(opts) || Garcon.global_io_executor
      @timer_executor = SingleThreadExecutor.new
      @condition      = Condition.new
      init_executor
      enable_at_exit_handler!(opts)
    end

    # Post a task to be execute run after a given delay (in seconds). If the
    # delay is less than 1/100th of a second the task will be immediately post
    # to the executor.
    #
    # @param [Float] delay
    #   The number of seconds to wait for before executing the task.
    #
    # @yield the task to be performed.
    #
    # @raise [ArgumentError] f the intended execution time is not in the future.
    #
    # @raise [ArgumentError] if no block is given.
    #
    # @return [Boolean]
    #   True if the message is post, false after shutdown.
    #
    def post(delay, *args, &task)
      raise ArgumentError, 'no block given' unless block_given?
      delay = TimerSet.calculate_delay!(delay)

      mutex.synchronize do
        return false unless running?

        if (delay) <= 0.01
          @task_executor.post(*args, &task)
        else
          @queue.push(Task.new(Garcon.monotonic_time + delay, args, task))
          @timer_executor.post(&method(:process_tasks))
        end
      end

      @condition.signal
      true
    end

    # @!visibility private
    def <<(task)
      post(0.0, &task)
      self
    end

    # @!macro executor_method_shutdown
    def kill
      shutdown
    end

    # Schedule a task to be executed after a given delay (in seconds).
    #
    # @param [Float] delay
    #   The number of seconds to wait for before executing the task.
    #
    # @raise [ArgumentError] if the intended execution time is not in the future
    #
    # @raise [ArgumentError] if no block is given.
    #
    # @return [Float]
    #   The number of seconds to delay.
    #
    def self.calculate_delay!(delay)
      if delay.is_a?(Time)
        if delay <= now
          raise ArgumentError, 'schedule time must be in the future'
        end
        delay.to_f - now.to_f
      else
        if delay.to_f < 0.0
          raise ArgumentError, 'seconds must be greater than zero'
        end
        delay.to_f
      end
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    # A struct for encapsulating a task and its intended execution time.
    # It facilitates proper prioritization by overriding the comparison
    # (spaceship) operator as a comparison of the intended execution
    # times.
    #
    # @!visibility private
    Task = Struct.new(:time, :args, :op) do
      include Comparable

      def <=>(other)
        self.time <=> other.time
      end
    end

    private_constant :Task

    # @!visibility private
    def shutdown_execution
      @queue.clear
      @timer_executor.kill
      stopped_event.set
    end

    # Run a loop and execute tasks in the scheduled order and at the approximate
    # scheduled time. If no tasks remain the thread will exit gracefully so that
    # garbage collection can occur. If there are no ready tasks it will sleep
    # for up to 60 seconds waiting for the next scheduled task.
    #
    # @!visibility private
    def process_tasks
      loop do
        task = mutex.synchronize { @queue.peek }
        break unless task

        now = Garcon.monotonic_time
        diff = task.time - now

        if diff <= 0
          # We need to remove the task from the queue before passing it to the
          # executor, to avoid race conditions where we pass the peek'ed task
          # to the executor and then pop a different one that's been added in
          # the meantime.
          #
          # Note that there's no race condition between the peek and this pop -
          # this pop could retrieve a different task from the peek, but that
          # task would be due to fire now anyway (because @queue is a priority
          # queue, and this thread is the only reader, so whatever timer is at
          # the head of the queue now must have the same pop time, or a closer
          # one, as when we peeked).
          #
          task = mutex.synchronize { @queue.pop }
          @task_executor.post(*task.args, &task.op)
        else
          mutex.synchronize do
            @condition.wait(mutex, [diff, 60].min)
          end
        end
      end
    end
  end
end
