#!/usr/bin/env ruby

require 'find'
require 'exifr'
require 'fileutils'
require 'optparse'

require_relative 'lib/phile'
require_relative 'lib/dir_walker'
require_relative 'lib/phlogger'

class PhotoOrg
  VERSION = "2.0.0"
  
  def initialize
    @options = {
      parallel: ENV['PARALLEL'] == 'true',
      thread_count: (ENV['THREADS'] || 4).to_i,
      verbose: ENV['VERBOSE'] == 'true',
      batch_size: (ENV['BATCH_SIZE'] || 100).to_i,
      dry_run: ENV['DRY_RUN'] == 'true'
    }
  end

  def run(argv)
    return show_usage if argv.length < 2
    
    source_dir = argv[0]
    dest_dir = argv[1]
    
    # Validate directories
    unless Dir.exist?(source_dir)
      puts "Error: Source directory '#{source_dir}' does not exist."
      return 1
    end
    
    # Create destination directory if it doesn't exist
    FileUtils.mkdir_p(dest_dir) unless Dir.exist?(dest_dir)
    
    puts "Photo Organizer v#{VERSION}"
    puts "Source: #{source_dir}"
    puts "Destination: #{dest_dir}"
    puts "Options: #{@options}" if @options[:verbose]
    puts "Dry run mode - no files will be copied" if @options[:dry_run]
    puts

    log = Phlogger.new(source_dir, dest_dir)
    
    begin
      # Choose processing method based on configuration
      if @options[:parallel] && @options[:thread_count] > 1
        process_parallel(source_dir, dest_dir, log)
      else
        process_sequential(source_dir, dest_dir, log)
      end
      
      # Save performance logs
      log.save
      
      # Print summary
      print_summary(log)
      
      0 # Success
    rescue => e
      puts "Fatal error: #{e.message}"
      puts e.backtrace if @options[:verbose]
      1 # Error
    end
  end

  private

  def process_sequential(source_dir, dest_dir, log)
    puts "Processing files sequentially..."
    
    walker = DirWalker.new(source_dir, log)
    
    walker.walk_the_source_dir do |path|
      process_file(path, dest_dir, log)
    end
  end

  def process_parallel(source_dir, dest_dir, log)
    puts "Processing files in parallel with #{@options[:thread_count]} threads..."
    
    walker = DirWalker.new(source_dir, log)
    
    walker.walk_the_source_dir_parallel(thread_count: @options[:thread_count]) do |path|
      process_file(path, dest_dir, log)
    end
  end

  def process_file(path, dest_dir, log)
    phile = Phile.new(path, dest_dir, log)
    
    if @options[:dry_run]
      # In dry run mode, just calculate the destination path
      dest_path = phile.dest_path
      puts "Would copy: #{path} -> #{dest_path}" if @options[:verbose]
    else
      phile.copy
    end
    
    # Track performance periodically
    log.track_performance if log.respond_to?(:track_performance)
    
    # Print progress
    print_progress(log) if @options[:verbose] && log.processed_count % 50 == 0
  end

  def print_progress(log)
    total = log.total_files_found
    processed = log.processed_count
    
    if total > 0
      percentage = (processed.to_f / total * 100).round(1)
      puts "Progress: #{processed}/#{total} files (#{percentage}%)"
    else
      puts "Progress: #{processed} files processed"
    end
  end

  def print_summary(log)
    puts "\n" + "="*50
    puts "PROCESSING COMPLETE"
    puts "="*50
    
    duration = log.end_time - log.start_time
    files_per_second = log.processed_count > 0 ? (log.processed_count / duration).round(2) : 0
    
    puts "Files processed: #{log.processed_count}"
    puts "Unique files: #{log.unique_count}"
    puts "Same timestamp: #{log.same_timestamp_count}"
    puts "Duplicates: #{log.duplicates_count}"
    puts "Errors: #{log.error_count}"
    puts "Processing rate: #{files_per_second} files/second"
    puts "Duration: #{format_duration(duration)}"
    
    if log.error_count > 0
      puts "\n⚠ WARNING: #{log.error_count} errors occurred during processing."
      puts "Check the log files for details."
    end
    
    puts "\nLog files saved to: #{File.join(log.instance_variable_get(:@dest), 'stats.log')}"
  end

  def format_duration(seconds)
    hours = (seconds / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i
    secs = (seconds % 60).to_i
    
    if hours > 0
      "#{hours}h #{minutes}m #{secs}s"
    elsif minutes > 0
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  def show_usage
    puts <<~USAGE
      Photo Organizer v#{VERSION}
      
      Usage: ruby photo_org.rb SOURCE_DIR DEST_DIR
      
      Organizes photos by date in DEST_DIR/Year/Month/Day/Time.jpg format
      
      Environment Variables:
        PARALLEL=true         Enable parallel processing
        THREADS=4            Number of threads for parallel processing
        VERBOSE=true         Enable verbose output
        BATCH_SIZE=100       Number of files to process in each batch
        DRY_RUN=true         Preview mode - don't actually copy files
        TRACK_PERFORMANCE=true  Generate detailed performance logs
      
      Examples:
        ruby photo_org.rb /path/to/photos /path/to/organized
        PARALLEL=true THREADS=8 ruby photo_org.rb /path/to/photos /path/to/organized
        DRY_RUN=true ruby photo_org.rb /path/to/photos /path/to/organized
    USAGE
  end
end

# Run the application if this file is executed directly
if __FILE__ == $0
  exit_code = PhotoOrg.new.run(ARGV)
  exit(exit_code)
end