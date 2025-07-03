require 'json'

class Phlogger
  STATS_LOG_FILE = "stats.log"
  DUPLICATES_LOG_FILE = "duplicate_files.log"
  PERFORMANCE_LOG_FILE = "performance.log"

  attr_accessor :valid_exif_files_count, :invalid_exif_files_count, :invalid_ext_count
  attr_accessor :duplicates_count, :same_timestamp_count, :unique_count, :processed_count
  attr_accessor :error_count, :total_files_found, :start_time, :end_time

  def initialize source, dest
    @source = source
    @dest = dest
    @start_time = Time.now
    
    # Initialize all counters to 0
    reset_counters
    
    # Performance tracking
    @performance_data = {
      start_time: @start_time,
      memory_usage: [],
      processing_times: []
    }
  end

  def reset_counters
    self.duplicates_count = 0
    self.same_timestamp_count = 0
    self.unique_count = 0
    self.processed_count = 0
    self.valid_exif_files_count = 0
    self.invalid_exif_files_count = 0
    self.invalid_ext_count = 0
    self.error_count = 0
    self.total_files_found = 0
  end

  # Track performance metrics during processing
  def track_performance
    if @processed_count % 100 == 0  # Sample every 100 files
      @performance_data[:memory_usage] << {
        files_processed: @processed_count,
        memory_mb: memory_usage_mb,
        timestamp: Time.now
      }
    end
  end

  def save
    @end_time = Time.now
    @performance_data[:end_time] = @end_time
    
    # Write logs concurrently for better performance
    write_stats_log
    write_performance_log if ENV['TRACK_PERFORMANCE']
  end

  private

  def write_stats_log
    stats_path = File.join(@dest, STATS_LOG_FILE)
    
    # Use atomic write to prevent corruption
    temp_path = "#{stats_path}.tmp"
    
    File.open(temp_path, 'w') do |f|
      f.write(stats_content)
    end
    
    File.rename(temp_path, stats_path)
  end

  def write_performance_log
    perf_path = File.join(@dest, PERFORMANCE_LOG_FILE)
    
    File.open(perf_path, 'w') do |f|
      f.write(JSON.pretty_generate(@performance_data))
    end
  end

  def stats_content
    duration = @end_time - @start_time
    files_per_second = @processed_count > 0 ? (@processed_count / duration).round(2) : 0
    
    # Use heredoc with interpolation for better performance than string concatenation
    <<~EOS
      Photo Organizer - Processing Statistics
      =====================================
      
      Execution Details:
      Start Time: #{@start_time}
      End Time: #{@end_time}
      Duration: #{format_duration(duration)}
      
      Source Directory: #{@source}
      Destination Directory: #{@dest}
      
      File Processing:
      Total Files Found: #{total_files_found}
      Files Processed: #{processed_count}
      Processing Rate: #{files_per_second} files/second
      
      File Categories:
      ✓ Unique files: #{unique_count}
      ⚠ Files with same timestamp: #{same_timestamp_count}
      ⊗ Duplicate files: #{duplicates_count}
      ✗ Errors encountered: #{error_count}
      
      EXIF Data:
      Valid EXIF data: #{valid_exif_files_count}
      Invalid EXIF data: #{invalid_exif_files_count}
      Invalid extensions: #{invalid_ext_count}
      
      Memory Usage:
      Peak Memory: #{peak_memory_usage_mb} MB
      
      Performance Tips:
      #{performance_tips}
    EOS
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

  def memory_usage_mb
    # Get memory usage if available (Linux/Unix)
    if File.exist?('/proc/self/status')
      status = File.read('/proc/self/status')
      if match = status.match(/VmRSS:\s*(\d+)\s*kB/)
        return match[1].to_i / 1024  # Convert KB to MB
      end
    end
    
    # Fallback for other systems
    0
  end

  def peak_memory_usage_mb
    return 0 if @performance_data[:memory_usage].empty?
    
    @performance_data[:memory_usage].map { |data| data[:memory_mb] }.max
  end

  def performance_tips
    tips = []
    
    if error_count > 0
      tips << "• #{error_count} errors occurred. Check file permissions and disk space."
    end
    
    if duplicates_count > (processed_count * 0.1)  # More than 10% duplicates
      tips << "• High duplicate rate detected. Consider deduplication before organizing."
    end
    
    if same_timestamp_count > (processed_count * 0.05)  # More than 5% same timestamps
      tips << "• Many files have identical timestamps. Consider enabling microsecond precision."
    end
    
    duration = @end_time - @start_time
    if duration > 300 && processed_count > 1000  # More than 5 minutes for 1000+ files
      tips << "• Consider using parallel processing (PARALLEL=true) for large collections."
    end
    
    tips.empty? ? "No performance issues detected." : tips.join("\n      ")
  end
end