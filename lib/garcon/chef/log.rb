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

require 'mixlib/log/formatter'

module Mixlib
  module Log
    class Formatter < Logger::Formatter
      # Set Chef::Log::Formatter.show_time == true/false to enable/disable the
      # printing of the time with the message.

      def call(severity, time, progname, msg)
        format % [
          format_datetime(time).blue,
          format_severity(severity),
          msg2str(msg).strip
        ]
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def format
        "\n[%s] %5s: %s\n"
      end

      def format_severity(severity)
        case severity
        when 'FATAL'
          severity.bright_red
        when 'ERROR'
          severity.red
        when 'WARN'
          severity.yellow
        when 'DEBUG'
          severity.light_gray
        when 'INFO'
          severity.green
        else
          severity
        end
      end

      def format_datetime(time)
        time.strftime('%T')
      end
    end
  end
end
