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

require_relative 'executor'

module Garcon

  class RubySingleThreadExecutor
    include RubyExecutor
    include SerialExecutor

    # Create a new thread pool.
    #
    # @option opts [Symbol] :fallback_policy (:discard)
    #   The policy for handling new tasks that are received when the queue size
    #   has reached `max_queue` or after the executor has shut down.
    #
    def initialize(opts = {})
      @queue  = Queue.new
      @thread = nil
      @fallback_policy = opts.fetch(:fallback_policy, :discard)
      if !FALLBACK_POLICY.include?(fallback)
        raise ArgumentError, "#{fallback} is not a valid fallback policy"
      end
      init_executor
      enable_at_exit_handler!(opts)
    end

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    # @!visibility private
    def execute(*args, &task)
      supervise
      @queue << [args, task]
    end

    # @!visibility private
    def shutdown_execution
      @queue << :stop
      stopped_event.set unless alive?
    end

    # @!visibility private
    def kill_execution
      @queue.clear
      @thread.kill if alive?
    end

    # @!visibility private
    def alive?
      @thread && @thread.alive?
    end

    # @!visibility private
    def supervise
      @thread = new_worker_thread unless alive?
    end

    # @!visibility private
    def new_worker_thread
      Thread.new do
        Thread.current.abort_on_exception = false
        work
      end
    end

    # @!visibility private
    def work
      loop do
        task = @queue.pop
        break if task == :stop
        begin
          task.last.call(*task.first)
        rescue => e
          Chef::Log.debug "Caught exception => #{e}"
        end
      end
      stopped_event.set
    end
  end
end
