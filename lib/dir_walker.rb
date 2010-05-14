class DirWalker
  def initialize source_dir, exclude_dirs_like, log
    @source_dirs = [source_dir]
    @exclude_dirs_like = [exclude_dirs_like]
    @log = log
  end

  def walk_the_source_dir
    @source_dirs.each do |dir|
      Find.find(dir) do |path|
        if FileTest.directory?(path)
          if @exclude_dirs_like.include?(File.basename(path))
            Find.prune
          else
            next
          end
        else
          @log.processed_count +=1
          yield path
        end
      end
    end
  end
end