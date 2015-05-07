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
require_relative '../monotonic_time'

module Garcon

  # @!visibility private
  class ThreadPoolWorker

    # @!visibility private
    def initialize(queue, parent)
      @queue         = queue
      @parent        = parent
      @mutex         = Mutex.new
      @last_activity = Garcon.monotonic_time
      @thread        = nil
    end

    # @!visibility private
    def dead?
      return @mutex.synchronize do
        @thread.nil? ? false : ! @thread.alive?
      end
    end

    # @!visibility private
    def last_activity
      @mutex.synchronize { @last_activity }
    end

    def status
      @mutex.synchronize do
        return 'not running' if @thread.nil?
        @thread.status
      end
    end

    # @!visibility private
    def kill
      @mutex.synchronize do
        Thread.kill(@thread) unless @thread.nil?
        @thread = nil
      end
    end

    # @!visibility private
    def run(thread = Thread.current)
      @mutex.synchronize do
        raise StandardError, 'already running' unless @thread.nil?
        @thread = thread
      end

      loop do
        task = @queue.pop
        if task == :stop
          @thread = nil
          @parent.on_worker_exit(self)
          break
        end

        begin
          task.last.call(*task.first)
        rescue => e
          Chef::Log.debug "Caught exception => #{e}"
        ensure
          @last_activity = Garcon.monotonic_time
          @parent.on_end_task
        end
      end
    end
  end
end
