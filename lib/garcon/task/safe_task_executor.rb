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

module Garcon

  # A simple utility class that executes a callable and returns and array of
  # three elements:
  # * success: indicating if the callable has been executed without errors
  # * value:   filled by the callable result if it has been executed without
  #            errors, nil otherwise
  # * reason:  the error risen by the callable if it has been executed with
  #            errors, nil otherwise
  #
  class SafeTaskExecutor

    def initialize(task, opts = {})
      @task  = task
      @mutex = Mutex.new
      @ex    = opts.fetch(:rescue_exception, false) ? Exception : StandardError
    end

    # @return [Array]
    def execute(*args)
      @mutex.synchronize do
        success = false
        value   = reason = nil

        begin
          value    =  @task.call(*args)
          success  =  true
        rescue @ex => e
          reason   =  e
          success  =  false
        end

        [success, value, reason]
      end
    end
  end
end
