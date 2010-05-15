class DirWalker
  def initialize source_dir, log
    @source_dirs = [source_dir]
    @log = log
  end

  def walk_the_source_dir
    @source_dirs.each do |dir|
      Find.find(dir) do |path|
        if FileTest.directory?(path)
            next
        else
          @log.processed_count +=1
          yield path
        end
      end
    end
  end
end