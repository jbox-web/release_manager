module ReleaseManager
  class CLI < Thor

    desc 'release', 'Create a new release'
    option :bump, type: :string, default: 'patch'

    def release
      puts 'Creating release :'
      puts ''
      ReleaseManager::Release.release(options)
    end


    desc 'rollback', 'Rollback the last created release'

    def rollback
      puts 'Rolling back release :'
      puts ''
      ReleaseManager::Release.rollback
    end


    desc 'push', 'Push the release tag'

    def push
      puts 'Pushing release :'
      puts ''
      ReleaseManager::Release.push
    end


    desc 'info', 'Display infos about the current and the next release'
    option :bump, type: :string, default: 'patch'

    def info
      ReleaseManager::Release.info(options)
    end

  end
end
