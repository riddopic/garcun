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

module Garcon
  module Coercions
    class StringDefinitions
      def self.bind_to(coercer)
        # Attempt to parse the date. If it can't be parsed just return nil.
        # Silently failing is about the only thing I can think of.
        type_parser = -> (obj, target) do
          begin
            target.parse(obj)
          rescue ArgumentError
            nil
          end
        end

        coercer.register(String, Time, &type_parser)
        coercer.register(String, Date, &type_parser)
        coercer.register(String, DateTime, &type_parser)
        coercer.register(String, Integer)  { |obj, _| obj.to_i }
        coercer.register(String, Float) { |obj, _| obj.to_f }
        coercer.register(String, Boolean) do |string, _|
          %w(1 on t true y yes).include?(string.downcase)
        end
      end
    end
  end
end
