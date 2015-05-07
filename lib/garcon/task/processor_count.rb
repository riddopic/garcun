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

require 'rbconfig'
require_relative 'delay'

module Garcon

  class ProcessorCounter
    def initialize
      @processor_count          = Delay.new { compute_processor_count }
      @physical_processor_count = Delay.new { compute_physical_count }
    end

    # Number of processors seen by the OS and used for process scheduling. For
    # performance reasons the calculated value will be memoized on the first
    # call.
    #
    def processor_count
      @processor_count.value
    end

    # Number of physical processor cores on the current system. For performance
    # reasons the calculated value will be memoized on the first call.
    #
    def physical_processor_count
      @physical_processor_count.value
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    def compute_processor_count
      if RUBY_PLATFORM == 'java'
        java.lang.Runtime.getRuntime.availableProcessors
      else
        os_name = RbConfig::CONFIG["target_os"]
        if os_name =~ /mingw|mswin/
          require 'win32ole'
          result = WIN32OLE.connect("winmgmts://").ExecQuery(
            "select NumberOfLogicalProcessors from Win32_Processor")
          result.to_enum.collect(&:NumberOfLogicalProcessors).reduce(:+)
        elsif File.readable?("/proc/cpuinfo")
          IO.read("/proc/cpuinfo").scan(/^processor/).size
        elsif File.executable?("/usr/bin/hwprefs")
          IO.popen("/usr/bin/hwprefs thread_count").read.to_i
        elsif File.executable?("/usr/sbin/psrinfo")
          IO.popen("/usr/sbin/psrinfo").read.scan(/^.*on-*line/).size
        elsif File.executable?("/usr/sbin/ioscan")
          IO.popen("/usr/sbin/ioscan -kC processor") do |out|
            out.read.scan(/^.*processor/).size
          end
        elsif File.executable?("/usr/sbin/pmcycles")
          IO.popen("/usr/sbin/pmcycles -m").read.count("\n")
        elsif File.executable?("/usr/sbin/lsdev")
          IO.popen("/usr/sbin/lsdev -Cc processor -S 1").read.count("\n")
        elsif File.executable?("/usr/sbin/sysconf") and os_name =~ /irix/i
          IO.popen("/usr/sbin/sysconf NPROC_ONLN").read.to_i
        elsif File.executable?("/usr/sbin/sysctl")
          IO.popen("/usr/sbin/sysctl -n hw.ncpu").read.to_i
        elsif File.executable?("/sbin/sysctl")
          IO.popen("/sbin/sysctl -n hw.ncpu").read.to_i
        else
          1
        end
      end
    rescue
      return 1
    end

    def compute_physical_count
      ppc = case RbConfig::CONFIG["target_os"]
            when /darwin1/
              IO.popen("/usr/sbin/sysctl -n hw.physicalcpu").read.to_i
            when /linux/
              cores = {} # unique physical ID / core ID combinations
              phy   = 0
              IO.read("/proc/cpuinfo").scan(/^physical id.*|^core id.*/) do |ln|
                if ln.start_with?("physical")
                  phy = ln[/\d+/]
                elsif ln.start_with?("core")
                  cid        = phy + ":" + ln[/\d+/]
                  cores[cid] = true if not cores[cid]
                end
              end
              cores.count
            when /mswin|mingw/
              require 'win32ole'
              result_set = WIN32OLE.connect("winmgmts://").ExecQuery(
                "select NumberOfCores from Win32_Processor")
              result_set.to_enum.collect(&:NumberOfCores).reduce(:+)
            else
              processor_count
            end
      # fall back to logical count if physical info is invalid
      ppc > 0 ? ppc : processor_count
    rescue
      return 1
    end
  end

  # create the default ProcessorCounter on load
  @processor_counter = ProcessorCounter.new
  singleton_class.send :attr_reader, :processor_counter

  def self.processor_count
    processor_counter.processor_count
  end

  def self.physical_processor_count
    processor_counter.physical_processor_count
  end
end
