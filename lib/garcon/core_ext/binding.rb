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

class Binding

  # Returns the call stack, same format as Kernel#caller()
  #
  def caller( skip=0 )
    eval("caller(#{skip})")
  end

  # Return the line number on which the binding was created.
  #
  def __LINE__
    Kernel.eval("__LINE__", self)
  end

  # Returns file name in which the binding was created.
  #
  def __FILE__
    Kernel.eval("__FILE__", self)
  end

  # Return the directory of the file in which the binding was created.
  #
  def __DIR__
    File.dirname(self.__FILE__)
  end

  # Retreive the current running method.
  #
  def __method__
    Kernel.eval("__method__", self)
  end

  # Retreive the current running method.
  #
  def __callee__
    Kernel.eval("__callee__", self)
  end

  # Returns the call stack, in array format.
  def callstack(level=1)
    eval( "callstack( #{level} )" )
  end
  alias_method :call_stack, :callstack
end

