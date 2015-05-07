# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014-2015 Stefano Harding
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
  module Stash
    # Stash::Io handles background io, compaction and is the arbiter
    # of multiprocess safety.
    #
    # @api private
    class Journal < Queue
      attr_reader :size, :file

      def initialize(file, format, serializer, &block)
        super()
        @file, @format, @serializer, @emit = file, format, serializer, block
        open
        @worker = Thread.new(&method(:worker))
        @worker.priority = -1
        load
      end

      # Is the journal closed?
      #
      def closed?
        @fd.closed?
      end

      # Clear the queue and close the file handler
      #
      def close
        self << nil
        @worker.join
        @fd.close
        super
      end

      # Load new journal entries
      #
      def load
        flush
        replay
      end

      # Lock the logfile across thread and process boundaries
      #
      def lock
        flush
        with_flock(File::LOCK_EX) do
          replay
          result = yield
          flush
          result
        end
      end

      # Clear the database log and yield
      #
      def clear
        flush
        with_tmpfile do |path, file|
          file.write(@format.header)
          file.close
          with_flock(File::LOCK_EX) do
            File.rename(path, @file)
          end
        end
        open
      end

      # Compact the logfile to represent the in-memory state
      #
      def compact
        load
        with_tmpfile do |path, file|
          # Compactified database has the same size -> return
          return self if @pos == file.write(dump(yield, @format.header))
          with_flock(File::LOCK_EX) do
            if @pos != nil
              file.write(read)
              file.close
              File.rename(path, @file)
            end
          end
        end
        open
        replay
      end

      # Return byte size of journal
      #
      def bytesize
        @fd.stat.size
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      # Emit records as we parse them
      def replay
        buf = read
        @size += @format.parse(buf, &@emit)
      end

      # Open or reopen file
      #
      def open
        @fd.close if @fd
        @fd = File.open(@file, 'ab+')
        @fd.advise(:sequential) if @fd.respond_to? :advise
        stat = @fd.stat
        @inode = stat.ino
        write(@format.header) if stat.size == 0
        @pos = nil
      end

      # Read new file content
      #
      def read
        with_flock(File::LOCK_SH) do
          unless @pos
            @fd.pos = 0
            @format.read_header(@fd)
            @size = 0
            @emit.call(nil)
          else
            @fd.pos = @pos
          end
          buf = @fd.read
          @pos = @fd.pos
          buf
        end
      end

      # Return database dump as string
      #
      def dump(records, dump = '')
        records.each do |record|
          record[1] = @serializer.dump(record.last)
          dump << @format.dump(record)
        end
        dump
      end

      # Worker thread
      #
      def worker
        while (record = first)
          tries = 0
          begin
            if Hash === record
              write(dump(record))
              @size += record.size
            else
              record[1] = @serializer.dump(record.last) if record.size > 1
              write(@format.dump(record))
              @size += 1
            end
          rescue Exception => e
            tries += 1
            warn "Stash worker, try #{tries}: #{e.message}"
            tries <= 3 ? retry : raise
          ensure
            pop
          end
        end
      rescue Exception => e
        warn "Stash worker terminated: #{e.message}"
      end

      # Write data to output stream and advance @pos
      #
      def write(dump)
        with_flock(File::LOCK_EX) do
          @fd.write(dump)
          @fd.flush
        end
        @pos = @fd.pos if @pos && @fd.pos == @pos + dump.bytesize
      end

      # Block with file lock
      #
      def with_flock(mode)
        return yield if @locked
        begin
          loop do
            Thread.pass until @fd.flock(mode)
            stat = @fd.stat
            break if stat.nlink > 0 && stat.ino == @inode
            open
          end
          @locked = true
          yield
        ensure
          @fd.flock(File::LOCK_UN)
          @locked = false
        end
      end

      # Open temporary file and pass it to the block
      #
      def with_tmpfile
        path = [@file, $$.to_s(36), Thread.current.object_id.to_s(36)].join
        file = File.open(path, 'wb')
        yield(path, file)
      ensure
        file.close unless file.closed?
        File.unlink(path) if File.exists?(path)
      end
    end
  end
end
