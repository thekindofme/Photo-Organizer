class Phlogger
  STATS_LOG_FILE = "stats.log"
  DUPLICATES_LOG_FILE = "duplicate_files.log"

  attr_accessor :valid_exif_files_count, :invalid_exif_files_count, :invalid_ext_count
  attr_accessor :duplicates_count, :same_timestamp_count, :unique_count, :processed_count

  def initialize source, dest
    @source = source
    @dest = dest
    self.duplicates_count =self.same_timestamp_count = self.unique_count = self.processed_count = self.valid_exif_files_count = self.invalid_exif_files_count = self.invalid_ext_count = 0
  end

  def save
    File.open("#{@dest}#{File::SEPARATOR}#{STATS_LOG_FILE}", 'w') {|f| f.write(content) }
  end

  def content
    <<EOS
Time = #{Time.new}
Source Directory = #{@source}
Dest Directory = #{@dest}
Files with valid EXIF data = #{valid_exif_files_count}
Files with invalid EXIF data = #{invalid_exif_files_count}
Files with invalid_ext = #{invalid_ext_count}
Duplicate files = #{duplicates_count}
Files with same timestamp = #{same_timestamp_count}
Unique files = #{unique_count}
EOS
  end
end