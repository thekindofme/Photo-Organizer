class Phile
  OTHER_DIR = "Other"
  DUPLICATE_DIR = "Duplicates"
  
  # Image extensions that support EXIF
  IMAGE_EXTENSIONS = [".jpg", ".jpeg"].freeze
  
  def initialize source_path, dest_dir, log
    @source_path = source_path
    @dest_dir = dest_dir
    @log = log
    @file_stats = nil # Cache file stats
    @timestamp_cache = nil # Cache timestamp
    # Remove debug output for performance
  end

  def ext
    @ext ||= File.extname(@source_path).downcase
  end

  def is_image?
    IMAGE_EXTENSIONS.include?(ext)
  end

  # Cache file stats to reduce file system calls
  def file_stats
    @file_stats ||= File.stat(@source_path)
  end

  def timestamp
    return @timestamp_cache if @timestamp_cache
    
    @timestamp_cache = if is_image?
      begin
        exif_file = EXIFR::JPEG.new(@source_path)
        if exif_file.exif? && exif_file.date_time
          exif_file.date_time
        else
          file_stats.ctime
        end
      rescue => e
        # Fallback to file creation time if EXIF parsing fails
        file_stats.ctime
      end
    else
      file_stats.ctime
    end
    
    @timestamp_cache
  end

  def original_name
    @original_name ||= File.basename(@source_path)
  end

  def ideal_dest_path_without_ext
    @ideal_dest_path_without_ext ||= if is_image?
      ts = timestamp
      # Use string interpolation instead of concatenation for better performance
      "#{@dest_dir}/#{ts.year}/#{ts.strftime("%b")}/#{ts.strftime("%d - %a")}/#{ts.strftime("%p %I:%M:%S")}"
    else
      "#{@dest_dir}/#{OTHER_DIR}/#{File.basename(original_name, ext)}"
    end
  end

  def ideal_dest_path
    @ideal_dest_path ||= "#{ideal_dest_path_without_ext}#{ext}"
  end

  # Optimized alternative path generation with early exit
  def alt_dest_path
    base_path = ideal_dest_path_without_ext
    count = 1
    
    loop do
      alt_path = "#{base_path}-#{count}#{ext}"
      return alt_path unless File.exist?(alt_path)
      count += 1
      # Prevent infinite loops in edge cases
      break if count > 10000
    end
    
    # Fallback with timestamp if we hit the limit
    "#{base_path}-#{Time.now.to_i}#{ext}"
  end

  def duplicate_dest_path
    # Use timestamp instead of random for better reproducibility
    "#{@dest_dir}/#{DUPLICATE_DIR}/#{File.basename(original_name, ext)}-#{Time.now.to_i}#{ext}"
  end

  def file_with_same_name_exists?
    @file_exists_cache ||= File.exist?(ideal_dest_path)
  end

  # Optimized duplicate detection using file size first, then content
  def is_duplicate?
    return false unless file_with_same_name_exists?
    
    dest_path = ideal_dest_path
    
    # Quick size check first (much faster than full file comparison)
    return false unless file_stats.size == File.size(dest_path)
    
    # Only do expensive file comparison if sizes match
    FileUtils.compare_file(@source_path, dest_path)
  rescue => e
    # If comparison fails, treat as not duplicate to be safe
    false
  end

  def dest_path
    if file_with_same_name_exists?
      if is_duplicate?
        @log.duplicates_count += 1
        duplicate_dest_path
      else
        @log.same_timestamp_count += 1
        alt_dest_path
      end
    else
      @log.unique_count += 1
      ideal_dest_path
    end
  end

  def copy
    dest_path_v = dest_path
    dest_dir = File.dirname(dest_path_v)
    
    # Only create directory if it doesn't exist (reduces system calls)
    FileUtils.mkdir_p(dest_dir) unless Dir.exist?(dest_dir)
    
    begin
      FileUtils.cp(@source_path, dest_path_v)
      # Optional: only log in verbose mode or to file instead of stdout
      # puts "Copied #{@source_path} to #{dest_path_v}" if ENV['VERBOSE']
    rescue => e
      @log.error_count += 1 if @log.respond_to?(:error_count=)
      raise e
    end
  end
end