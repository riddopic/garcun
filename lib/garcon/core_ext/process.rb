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

module Process

  # Turns the current script into a daemon process
  # that detaches from the console. It can be shut
  # down with a TERM signal.
  #
  def self.daemon(nochdir = nil, noclose = nil)
    exit if fork
    Process.setsid
    exit if fork
    Dir.chdir '/' unless nochdir
    File.umask 0000
    unless noclose
      STDIN.reopen  '/dev/null'
      STDOUT.reopen '/dev/null', 'a'
      STDERR.reopen '/dev/null', 'a'
    end
    trap('TERM') { exit }
    return 0
  end unless respond_to?(:daemon)
end

