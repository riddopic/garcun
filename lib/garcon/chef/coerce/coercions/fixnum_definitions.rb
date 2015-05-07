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
    class FixnumDefinitions
      def self.bind_to(coercer)
        coercer.register(Fixnum, String)   { |obj, _| obj.to_s }
        coercer.register(Fixnum, Time)     { |obj, _| Time.at(obj) }
        coercer.register(Fixnum, Date)     { |obj, _| Time.at(obj).to_date }
        coercer.register(Fixnum, DateTime) { |obj, _| Time.at(obj).to_datetime }
        coercer.register(Fixnum, String)   { |obj, _| obj.to_s }
        coercer.register(Fixnum, Integer)  { |obj, _| obj.to_i }
        coercer.register(Fixnum, Float)    { |obj, _| obj.to_f }
      end
    end
  end
end
