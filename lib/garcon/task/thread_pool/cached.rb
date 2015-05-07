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

  # A thread pool that dynamically grows and shrinks to fit the current
  # workload. New threads are created as needed, existing threads are reused,
  # and threads that remain idle for too long are killed and removed from the
  # pool. These pools are particularly suited to applications that perform a
  # high volume of short-lived tasks.
  #
  # On creation a `CachedThreadPool` has zero running threads. New threads are
  # created on the pool as new operations are `#post`. The size of the pool
  # will grow until `#max_length` threads are in the pool or until the number
  # of threads exceeds the number of running and pending operations. When a new
  # operation is post to the pool the first available idle thread will be
  # tasked with the new operation.
  #
  # Should a thread crash for any reason the thread will immediately be removed
  # from the pool. Similarly, threads which remain idle for an extended period
  # of time will be killed and reclaimed. Thus these thread pools are very
  # efficient at reclaiming unused resources.
  #
  class CachedThreadPool < ThreadPoolExecutor
    # Create a new thread pool.
    #
    # @param [Hash] opts
    #   The options defining pool behavior.
    #
    # @raise [ArgumentError] if `fallback` is not a known policy
    #
    # @option opts [Symbol] :fallback (`:abort`)
    #   The fallback policy
    #
    # @api public
    def initialize(opts = {})
      fallback = opts.fetch(:fallback, :abort)

      unless FALLBACK_POLICY.include?(fallback)
        raise ArgumentError, "#{fallback} is not a valid fallback policy"
      end

      opts = opts.merge(
        min_threads: 0,
        max_threads: DEFAULT_MAX_POOL_SIZE,
        fallback:    fallback,
        max_queue:   DEFAULT_MAX_QUEUE_SIZE,
        idletime:    DEFAULT_THREAD_IDLETIMEOUT)

      super(opts)
    end
  end
end
