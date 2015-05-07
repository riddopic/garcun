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

module Garcon
  module Stash
    class Queue
      def initialize
        @queue, @full, @empty = [], [], []
        @stop = false
        @heartbeat = Thread.new(&method(:heartbeat))
        @heartbeat.priority = -9
      end

      def <<(x)
        @queue << x
        thread = @full.first
        thread.wakeup if thread
      end

      def pop
        @queue.shift
        if @queue.empty?
          thread = @empty.first
          thread.wakeup if thread
        end
      end

      def first
        while @queue.empty?
          begin
            @full << Thread.current
            Thread.stop while @queue.empty?
          ensure
            @full.delete(Thread.current)
          end
        end
        @queue.first
      end

      def flush
        until @queue.empty?
          begin
            @empty << Thread.current
            Thread.stop until @queue.empty?
          ensure
            @empty.delete(Thread.current)
          end
        end
      end

      def close
        @stop = true
        @heartbeat.join
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def heartbeat
        until @stop
          @empty.each(&:wakeup)
          @full.each(&:wakeup)
          sleep 0.1
        end
      end
    end
  end
end
