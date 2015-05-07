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

class Struct

  # Get or set state of object. You can think of #object_state as an in-code
  # form of marshalling.
  #
  def object_state(data=nil)
    if data
      data.each_pair {|k,v| send(k.to_s + "=", v)}
    else
      data = {}
      each_pair{|k,v| data[k] = v}
      data
    end
  end

  # Get a hash with names and values of all instance variables.
  #
  # @example
  #   class Foo < Struct.new(:name, :age, :gender); end
  #   f = Foo.new("Jill", 50, :female)
  #   f.attributes   # => {:name => "Jill", :age => 50, :gender => :female}
  #
  # @return [Hash]
  #   Hash of instance variables in receiver, keyed by ivar name
  def attributes
    h = {}
    each_pair { |key, value| h[key] = value }
    h
  end
end
