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

require_relative 'dereferenceable'
require_relative 'observable'
require_relative 'atomic_boolean'
require_relative 'executor'
require_relative 'safe_task_executor'

module Garcon

  # A very common currency pattern is to run a thread that performs a task at
  # regular intervals. The thread that performs the task sleeps for the given
  # interval then wakes up and performs the task. Lather, rinse, repeat... This
  # pattern causes two problems. First, it is difficult to test the business
  # logic of the task because the task itself is tightly coupled with the
  # concurrency logic. Second, an exception raised while performing the task can
  # cause the entire thread to abend. In a long-running application where the
  # task thread is intended to run for days/weeks/years a crashed task thread
  # can pose a significant problem. `TimerTask` alleviates both problems.
  #
  # When a `TimerTask` is launched it starts a thread for monitoring the
  # execution interval. The `TimerTask` thread does not perform the task,
  # however. Instead, the TimerTask launches the task on a separate thread.
  # Should the task experience an unrecoverable crash only the task thread will
  # crash. This makes the `TimerTask` very fault tolerant Additionally, the
  # `TimerTask` thread can respond to the success or failure of the task,
  # performing logging or ancillary operations. `TimerTask` can also be
  # configured with a timeout value allowing it to kill a task that runs too
  # long.
  #
  # One other advantage of `TimerTask` is that it forces the business logic to
  # be completely decoupled from the concurrency logic. The business logic can
  # be tested separately then passed to the `TimerTask` for scheduling and
  # running.
  #
  # In some cases it may be necessary for a `TimerTask` to affect its own
  # execution cycle. To facilitate this, a reference to the TimerTask instance
  # is passed as an argument to the provided block every time the task is
  # executed.
  #
  # The `TimerTask` class includes the `Dereferenceable` mixin module so the
  # result of the last execution is always available via the `#value` method.
  # Derefencing options can be passed to the `TimerTask` during construction or
  # at any later time using the `#set_deref_options` method.
  #
  # `TimerTask` supports notification through the Ruby standard library
  # {http://ruby-doc.org/stdlib-2.0/libdoc/observer/rdoc/Observable.html
  # Observable} module. On execution the `TimerTask` will notify the observers
  # with three arguments: time of execution, the result of the block (or nil on
  # failure), and any raised exceptions (or nil on success). If the timeout
  # interval is exceeded the observer will receive a `Garcon::TimeoutError`
  # object as the third argument.
  #
  # @example Basic usage
  #   tt = Garcon::TimerTask.new { puts 'Run! Go! Execute! GO! GO! GO!' }
  #   tt.execute
  #
  #   tt.execution_interval # => 60 (default)
  #   tt.timeout_interval   # => 30 (default)
  #
  #   # wait 60 seconds...
  #   # => 'Run! Go! Execute! GO! GO! GO!'
  #
  #   tt.shutdown # => true
  #
  # @example Configuring `:execution_interval` and `:timeout_interval`
  #   tt = Garcon::TimerTask.new(execution_interval: 5, timeout_interval: 5) do
  #     puts 'Execute! Execute! GO! GO! GO!'
  #   end
  #
  #   tt.execution_interval # => 5
  #   tt.timeout_interval   # => 5
  #
  # @example Immediate execution with `:run_now`
  #   tt = Garcon::TimerTask.new(run_now: true) { puts 'GO! GO! GO!' }
  #   tt.execute
  #
  #   # => 'GO! GO! GO!'
  #
  # @example Last `#value` and `Dereferenceable` mixin
  #   tt = Garcon::TimerTask.new(dup_on_deref: true, execution_interval: 5) do
  #     Time.now
  #   end
  #
  #   tt.execute
  #   Time.now   # => 2015-03-21 08:56:50 -0700
  #   sleep(10)
  #   tt.value   # => 2015-03-21 08:56:55 -0700
  #
  # @example Controlling execution from within the block
  #   timer_task = Garcon::TimerTask.new(execution_interval: 1) do |task|
  #     task.execution_interval.times { print 'Execute! ' }
  #     print "\n"
  #     task.execution_interval += 1
  #     if task.execution_interval > 5
  #       puts 'Executed...'
  #       task.shutdown
  #     end
  #   end
  #
  #   timer_task.execute # blocking call - this task will stop itself
  #   # => Execute!
  #   # => Execute! Execute!
  #   # => Execute! Execute! Execute!
  #   # => Execute! Execute! Execute! Execute!
  #   # => Execute! Execute! Execute! Execute! Execute!
  #   # => Executed...
  #
  # @example Observation
  #   class TaskObserver
  #     def update(time, result, ex)
  #       if result
  #         print "(#{time}) Execution successfully returned #{result}\n"
  #       elsif ex.is_a?(Garcon::TimeoutError)
  #         print "(#{time}) Execution timed out\n"
  #       else
  #         print "(#{time}) Execution failed with error #{ex}\n"
  #       end
  #     end
  #   end
  #
  #   tt = Garcon::TimerTask.new(execution_interval: 1, timeout_interval: 1) {
  #     42
  #   }
  #   tt.add_observer(TaskObserver.new)
  #   tt.execute
  #
  #   # => (2015-03-21 09:06:07 -0700) Execution successfully returned 42
  #   # => (2015-03-21 09:06:08 -0700) Execution successfully returned 42
  #   # => (2015-03-21 09:06:09 -0700) Execution successfully returned 42
  #   tt.shutdown
  #
  #   tt = Garcon::TimerTask.new(execution_interval: 1, timeout_interval: 1) {
  #     sleep
  #   }
  #   tt.add_observer(TaskObserver.new)
  #   tt.execute
  #
  #   # => (2015-03-21 09:07:10 -0700) Execution timed out
  #   # => (2015-03-21 09:07:12 -0700) Execution timed out
  #   # => (2015-03-21 09:07:14 -0700) Execution timed out
  #   tt.shutdown
  #
  #   tt = Garcon::TimerTask.new(execution_interval: 1) { raise StandardError }
  #   tt.add_observer(TaskObserver.new)
  #   tt.execute
  #
  #   # => (2015-03-21 09:12:11 -0700) Execution failed with error StandardError
  #   # => (2015-03-21 09:12:12 -0700) Execution failed with error StandardError
  #   # => (2015-03-21 09:12:13 -0700) Execution failed with error StandardError
  #   tt.shutdown
  #
  class TimerTask
    include Dereferenceable
    include RubyExecutor
    include Observable

    # Default :execution_interval in seconds.
    EXECUTION_INTERVAL = 60

    # Default :timeout_interval in seconds.
    TIMEOUT_INTERVAL = 30

    # Create a new TimerTask with the given task and configuration.
    #
    # @!macro [attach] timer_task_initialize
    #   @note
    #     Calls Garcon::Dereferenceable#  set_deref_options passing opts. All
    #     options supported by Garcon::Dereferenceable can be set during object
    #     initialization.
    #
    #   @param [Hash] opts
    #     The options defining task execution.
    #   @option opts [Integer] :execution_interval
    #     The number of seconds between task executions (defaults to:
    #     EXECUTION_INTERVAL)
    #   @option opts [Integer] :timeout_interval
    #     The number of seconds a task can run before it is considered to have
    #     failed (default: TIMEOUT_INTERVAL)
    #   @option opts [Boolean] :run_now
    #     Whether to run the task immediately upon instantiation or to wait
    #     until the first execution_interval has passed (default: false)
    #
    #   @raise ArgumentError
    #     when no block is given.
    #
    #   @yield to the block after :execution_interval seconds have passed since
    #     the last yield
    #   @yieldparam task a reference to the TimerTask instance so that the
    #     block can control its own lifecycle. Necessary since self will
    #     refer to the execution context of the block rather than the running
    #     TimerTask.
    #
    #   @return [TimerTask]
    #     the new TimerTask.
    #
    #   @see Garcon::Dereferenceable#  set_deref_options
    def initialize(opts = {}, &task)
      raise ArgumentError.new('no block given') unless block_given?

      init_executor
      set_deref_options(opts)

      self.execution_interval =
        opts[:execution] || opts[:execution_interval] || EXECUTION_INTERVAL

      self.timeout_interval =
        opts[:timeout]   || opts[:timeout_interval]   || TIMEOUT_INTERVAL

      @run_now  = opts[:now] || opts[:run_now]
      @executor = Garcon::SafeTaskExecutor.new(task)
      @running  = Garcon::AtomicBoolean.new(false)

      self.observers = CopyOnNotifyObserverSet.new
    end

    # Is the executor running?
    #
    # @return [Boolean]
    #   True when running, false when shutting down or shutdown
    def running?
      @running.true?
    end

    # Execute a previously created TimerTask.
    #
    # @example Instance and execute in separate steps
    #   tt = Garcon::TimerTask.new(execution_interval: 10) { puts 'Sup!' }
    #   tt.running? # => false
    #   tt.execute
    #   tt.running? # => true
    #
    # @example Instance and execute in one line
    #   tt = Garcon::TimerTask.new(execution_interval: 10) { puts 'hi' }.execute
    #   tt.running? # => true
    #
    # @return [TimerTask]
    #   A reference to self.
    def execute
      mutex.synchronize do
        if @running.false?
          @running.make_true
          schedule_next_task(@run_now ? 0 : @execution_interval)
        end
      end
      self
    end

    # Create and execute a new TimerTask.
    #
    # @!macro timer_task_initialize
    #
    # @example
    #   task = Garcon::TimerTask.execute(execution_interval: 10) do
    #     puts 'Sappening d00d?'
    #   end
    #   task.running? # => true
    def self.execute(opts = {}, &task)
      TimerTask.new(opts, &task).execute
    end

    # @!attribute [rw] execution_interval
    # @return [Fixnum]
    #   Number of seconds after the task completes before it is performed again.
    def execution_interval
      mutex.lock
      @execution_interval
    ensure
      mutex.unlock
    end

    # @!attribute [rw] execution_interval
    # @return [Fixnum]
    #   Number of seconds after the task completes before it is performed again.
    def execution_interval=(value)
      if (value = value.to_f) <= 0.0
        raise ArgumentError.new 'must be greater than zero'
      else
        begin
          mutex.lock
          @execution_interval = value
        ensure
          mutex.unlock
        end
      end
    end

    # @!attribute [rw] timeout_interval
    # @return [Fixnum]
    #   Number of seconds the task can run before it is considered failed.
    def timeout_interval
      mutex.lock
      @timeout_interval
    ensure
      mutex.unlock
    end

    # @!attribute [rw] timeout_interval
    # @return [Fixnum]
    #   Number of seconds the task can run before it is considered failed.
    def timeout_interval=(value)
      if (value = value.to_f) <= 0.0
        raise ArgumentError.new('must be greater than zero')
      else
        begin
          mutex.lock
          @timeout_interval = value
        ensure
          mutex.unlock
        end
      end
    end

    private :post, :<<

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    # @!visibility private
    def shutdown_execution
      @running.make_false
      super
    end

    # @!visibility private
    def kill_execution
      @running.make_false
      super
    end

    # @!visibility private
    def schedule_next_task(interval = execution_interval)
      Garcon::timer(interval, Garcon::Event.new, &method(:execute_task))
    end

    # @!visibility private
    def execute_task(completion)
      return unless @running.true?
      Garcon::timer(execution_interval, completion, &method(:timeout_task))
      _success, value, reason = @executor.execute(self)
      if completion.try?
        self.value = value
        schedule_next_task
        time = Time.now
        observers.notify_observers do
          [time, self.value, reason]
        end
      end
    end

    # @!visibility private
    def timeout_task(completion)
      return unless @running.true?
      if completion.try?
        self.value = value
        schedule_next_task
        observers.notify_observers(Time.now, nil, Garcon::TimeoutError.new)
      end
    end
  end
end
