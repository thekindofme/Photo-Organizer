require 'find'

class DirWalker
  # Common image and video extensions to filter early
  SUPPORTED_EXTENSIONS = %w[.jpg .jpeg .png .gif .bmp .tiff .tif .raw .cr2 .nef .arw .dng .mov .mp4 .avi .mkv].freeze
  
  def initialize source_dir, log
    @source_dirs = Array(source_dir) # Handle both string and array input
    @log = log
    @processed_files = []
  end

  def walk_the_source_dir(&block)
    # Pre-filter files by extension for better performance
    eligible_files = collect_eligible_files
    
    @log.total_files_found = eligible_files.size
    
    # Process files in batches to manage memory usage
    batch_size = ENV['BATCH_SIZE']&.to_i || 100
    
    eligible_files.each_slice(batch_size) do |file_batch|
      process_batch(file_batch, &block)
    end
  end

  private

  def collect_eligible_files
    files = []
    
    @source_dirs.each do |dir|
      next unless Dir.exist?(dir)
      
      Find.find(dir) do |path|
        # Skip directories
        next if File.directory?(path)
        
        # Skip hidden files and system files
        next if File.basename(path).start_with?('.')
        
        # Pre-filter by extension to avoid processing unsupported files
        ext = File.extname(path).downcase
        next if ext.empty? || !SUPPORTED_EXTENSIONS.include?(ext)
        
        # Skip symbolic links to avoid potential issues
        next if File.symlink?(path)
        
        # Basic file accessibility check
        next unless File.readable?(path)
        
        files << path
      end
    end
    
    files
  end

  def process_batch(file_batch, &block)
    file_batch.each do |path|
      begin
        @log.processed_count += 1
        yield path
      rescue => e
        @log.error_count += 1 if @log.respond_to?(:error_count=)
        puts "Error processing #{path}: #{e.message}" if ENV['VERBOSE']
        # Continue processing other files even if one fails
      end
    end
  end

  # Optional: Add parallel processing support
  def walk_the_source_dir_parallel(thread_count: 4, &block)
    return walk_the_source_dir(&block) if thread_count <= 1
    
    require 'thread'
    
    eligible_files = collect_eligible_files
    @log.total_files_found = eligible_files.size
    
    # Create a thread-safe queue
    queue = Queue.new
    eligible_files.each { |file| queue << file }
    
    # Signal end of work
    thread_count.times { queue << nil }
    
    # Create worker threads
    threads = Array.new(thread_count) do
      Thread.new do
        while (file = queue.pop)
          begin
            @log.processed_count += 1
            yield file
          rescue => e
            @log.error_count += 1 if @log.respond_to?(:error_count=)
            puts "Error processing #{file}: #{e.message}" if ENV['VERBOSE']
          end
        end
      end
    end
    
    # Wait for all threads to complete
    threads.each(&:join)
  end
end