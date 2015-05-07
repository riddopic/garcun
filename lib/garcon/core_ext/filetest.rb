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

module FileTest

  SEPARATOR_PATTERN = (
    if File::ALT_SEPARATOR
      /[#{Regexp.quote File::ALT_SEPARATOR}#{Regexp.quote File::SEPARATOR}]/
    else
      /#{Regexp.quote File::SEPARATOR}/
    end
  ).freeze

  module_function

  # Predicate method for testing whether a path is absolute.
  # It returns +true+ if the pathname begins with a slash.
  def absolute?(path)
    !relative?(path)
  end

  # The opposite of #absolute?
  def relative?(path)
    while r = chop_basename(path.to_s)
      path, _ = r
    end
    path == ''
  end

  # List File.split, but preserves the file separators.
  #
  #   FileTest.chop_basename('/usr/lib') #=> ['/usr/', 'lib']
  #   FileTest.chop_basename('/') #=> nil
  #
  # Returns Array of `[pre-basename, basename]` or `nil`.
  #
  # This method is here simply to support the #relative? and #absolute? methods.
  def chop_basename(path)
    base = File.basename(path)
    if /\A#{SEPARATOR_PATTERN}?\z/ =~ base
      return nil
    else
      return path[0, path.rindex(base)], base
    end
  end
end
