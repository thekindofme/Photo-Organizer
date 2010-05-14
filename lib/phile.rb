class Phile
  OTHER_DIR = "Other"
  DUPLICATE_DIR = "Duplicates"

  def initialize source_path, dest_dir, log
    @source_path = source_path
    @dest_dir = dest_dir
    @log = log
    p "init #{@source_path}"
  end

  def ext
    File.extname(@source_path.downcase)
  end

  def is_image?
    [".jpg", ".jpeg"].include? ext
  end

  def timestamp
    exif_file = EXIFR::JPEG.new @source_path
    if exif_file.exif? && exif_file.date_time
      return exif_file.date_time
    else
      return File.new(@source_path).ctime
    end
  end

  def original_name
    File.basename @source_path
  end

  def ideal_dest_path_without_ext
    if is_image?
      return "#{@dest_dir}#{File::SEPARATOR}#{timestamp.year}#{File::SEPARATOR}#{timestamp.strftime("%b")}#{File::SEPARATOR}#{timestamp.strftime("%d - %a")}#{File::SEPARATOR}#{timestamp.strftime("%p %I:%M:%S")}"
    else
      return "#{@dest_dir}#{File::SEPARATOR}#{OTHER_DIR}#{File::SEPARATOR}#{original_name}".split(".")[0]
    end
  end

  def ideal_dest_path
    return "#{ideal_dest_path_without_ext}#{ext}"
  end

  def alt_dest_path
    count = 0
    while true
      alt_path = "#{ideal_dest_path_without_ext}-#{count}#{ext}"
      return alt_path unless File.exists? alt_path
      count += 1
    end
  end

  def duplicate_dest_path
    "#{@dest_dir}#{File::SEPARATOR}#{DUPLICATE_DIR}#{File::SEPARATOR}#{original_name}-#{rand(212141)}#{ext}"
  end

  def file_with_same_name_exists?
    File.exists? ideal_dest_path
  end

  def is_duplicate?
    file_with_same_name_exists? && FileUtils.compare_file(@source_path, ideal_dest_path)
  end

  def dest_path
      if file_with_same_name_exists?
        if is_duplicate?
          @log.duplicates_count=+1
          return duplicate_dest_path
        end
        @log.same_timestamp_count=+1
        return alt_dest_path
      else
        @log.unique_count=+1
        return ideal_dest_path
      end
  end

  def copy
    dest_path_v = dest_path
    FileUtils.mkdir_p File.dirname dest_path_v
    FileUtils.cp  @source_path, dest_path_v
    p "copied #{@source_path} to #{dest_path_v}"
  end
end