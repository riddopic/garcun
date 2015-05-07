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

require_relative 'uber/options'
require_relative 'uber/inheritable_attr'

# No not that kind! callback hooks.
#
module Garcon
  module Hookers
    module ClassMethods
      def define_hookers(*names)
        options = extract_options!(names)
        names.each { |name| setup_hooker(name, options) }
      end
      alias_method :define_hooker, :define_hookers

      def run_hooker(name, *args)
        run_hooker_for(name, self, *args)
      end

      def run_hooker_for(name, scope, *args)
        _hookers[name].run(scope, *args)
      end

      def callbacks_for_hooker(name)
        _hookers[name]
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def setup_hooker(name, options)
        _hookers[name] = Hooker.new(options)
        define_hooker_writer(name)
      end

      def define_hooker_writer(name)
        instance_eval(*hooker_writer_args(name))
      end

      def hooker_writer_args(name)
        str = <<-RUBY_EVAL
          def #{name}(method=nil, &block)
            _hookers[:#{name}] << (block || method)
          end
        RUBY_EVAL

        [str, __FILE__, __LINE__ + 1]
      end

      def extract_options!(args)
        args.last.is_a?(Hash) ? args.pop : {}
      end

      def included(descendant)
        descendant.class_eval do
          extend Uber::InheritableAttr
          extend ClassMethods
          inheritable_attr :_hookers
          self._hookers = BunchOfHookers.new
        end
      end
    end

    extend ClassMethods

    def run_hooker(name, *args)
      self.class.run_hooker_for(name, self, *args)
    end

    class BunchOfHookers < Hash
      def [](name)
        super(name.to_sym)
      end

      def []=(name, values)
        super(name.to_sym, values)
      end

      def clone
        super.tap do |cloned|
          each { |name, callbacks| cloned[name] = callbacks.clone }
        end
      end
    end

    class Hooker < Array
      def initialize(options)
        super()
        @options = options
      end

      def run(scope, *args)
        inject(Results.new) do |results, callback|
          executed = execute_callback(scope, callback, *args)

          return results.halted! unless continue_execution?(executed)
          results << executed
        end
      end

      def <<(callback)
        super Uber::Options::Value.new(callback, dynamic: true)
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def execute_callback(scope, callback, *args)
        callback.evaluate(scope, *args)
      end

      def continue_execution?(result)
        @options[:halts_on_falsey] ? result : true
      end

      class Results < Array
        def initialize(*)
          super
          @halted = false
        end

        def halted!
          @halted = true
          self
        end

        def halted?
          @halted
        end

        def not_halted?
          not @halted
        end
      end
    end

    module InstanceHookers
      include ClassMethods

      def run_hooker(name, *args)
        run_hooker_for(name, self, *args)
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def _hookers
        @_hookers ||= self.class._hookers.clone
      end

      module ClassMethods
        def define_hooker_writer(name)
          super
          class_eval(*hooker_writer_args(name))
        end
      end

      def self.included(descendant)
        descendant.extend(ClassMethods)
      end
    end
  end
end
