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

# The version number of the Garcon Gem
#
# @return [String]
#
# @api public
module Garcon
  # Contains information about this gem's version
  module Version
    MAJOR = 0
    MINOR = 0
    PATCH = 8

    # Returns a version string by joining MAJOR, MINOR, and PATCH with '.'
    #
    # @example
    #   Version.string # => '1.0.1'
    #
    def self.string
      [MAJOR, MINOR, PATCH].join('.')
    end

    def self.logo
      puts <<-EOF

                            .:  ;:. .:;S;:. .:;.;:. .:;S;:. .:;S;:.
                            S   ' S S  S    S  S    S     S  /
                            `:;S;:' `:;S;:' `:;S;:' `:;S;:' `:;S;:'
            .g8"""bgd
          .dP'     `M
          dM'       `  ,6"Yb.  `7Mb,od8 ,p6"bo   ,pW"Wq.`7MMpMMMb.
          MM          8)   MM    MM' "'6M'  OO  6W'   `Wb MM    MM
          MM.    `7MMF',pm9MM    MM    8M       8M     M8 MM    MM
          `Mb.     MM 8M   MM    MM    YM.    , YA.   ,A9 MM    MM
            `"bmmmdPY `Moo9^Yo..JMML.   YMbmd'   `Ybmd9'.JMML  JMML.
                                          bog
                                           od              V #{string}

      EOF
    end
  end

  VERSION = Garcon::Version.string
end
