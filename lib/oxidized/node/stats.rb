require 'json'
require 'fileutils'

module Oxidized
  class Node
    class Stats
      attr_reader :mtimes

      MAX_STAT = 10
      HIST_DIR = "/home/oxidized/.config/oxidized"

      # @param [Job] job job whose information is added to stats
      # @return [void]
      def add(job)
        stat = {
          start: job.start,
          end:   job.end,
          time:  job.time
        }
        @stats[job.status] ||= []
        @stats[job.status].shift if @stats[job.status].size > @history_size
        @stats[job.status].push stat
        @stats[:counter][job.status] += 1

        save_to_file  # Save stats to file after each update
      end

      # @param [Symbol] status stats for specific status
      # @return [Hash,Array] Hash of stats for every status or Array of stats for specific status
      def get(status = nil)
        status ? @stats[status] : @stats
      end

      def get_counter(counter = nil)
        counter ? @stats[:counter][counter] : @stats[:counter]
      end

      def successes
        @stats[:counter][:success]
      end

      def failures
        @stats[:counter].reduce(0) { |m, h| h[0] == :success ? m : m + h[1] }
      end

      def mtime
        mtimes.last
      end

      def update_mtime
        @mtimes.push Time.now.utc
        @mtimes.shift
      end

      private

      def initialize
        @history_size = Oxidized.config.stats.history_size? || MAX_STAT
        @history_dir = Oxidized.config.stats.history_dir? || HIST_DIR
        @mtimes = Array.new(@history_size, "unknown")
        @stats  = {}
        @stats[:counter] = Hash.new(0)
        load_from_file  # Load stats from the file (if available) during initialization
      end

      # Save the current stats to a JSON file in the specified directory
      def save_to_file
        # Ensure the directory exists

        stats_file = File.join(@history_dir, "stats.json")
        File.open(stats_file, 'w') do |f|
          f.write(@stats.to_json)
        end
      end

      # Load stats from a JSON file (if the file exists)
      def load_from_file
        stats_file = File.join(@history_dir, "stats.json")
        return unless File.exist?(stats_file)

        file_data = File.read(stats_file)
        @stats = JSON.parse(file_data, symbolize_names: true)
      rescue JSON::ParserError
        puts "Error parsing stats file, using default stats."
        @stats = { counter: Hash.new(0) }  # Reset to default if parsing fails
      end
    end
  end
end
