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
    class TimeDefinitions
      def self.bind_to(coercer)
        coercer.register(Time, Date)     { |obj, _| obj.to_date }
        coercer.register(Time, DateTime) { |obj, _| obj.to_datetime }
        coercer.register(Time, Integer)  { |obj, _| obj.to_i }
        coercer.register(Time, Float)    { |obj, _| obj.to_f }
        coercer.register(Time, String)   { |obj, _| obj.to_s }
      end
    end
  end
end
