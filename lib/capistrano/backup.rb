require 'capistrano/backup/plan'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/backup requires Capistrano 2"
end

Capistrano::Configuration.instance(true).load do
  require 'yaml'
  require 'git'

  def _cset(name, *args, &block)
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  # TODO implement notifications
  def notify(message)
    logger.info("TODO: Would have sent notfication: #{message} to #{notify_emails}") if notify_emails
  end

  # targets
  _cset(:repo)                { abort "Please specify the repository that houses your backup configuration (:repo)" }
  _cset(:targets_path)        { about "Please specify the local path to the targets configuration files (:targets_path)" }

  # remote information
  _cset(:user)                { ENV['USER'] }
  _cset(:deploy_to)           { abort "Please specify the remote backup target path (:deploy_to)" }
  _cset(:backup_filemode)     { 0600 }
    
  # file information
  _cset :backups_dir,         'backups'
  _cset(:backups_path)        { File.join(deploy_to, backups_dir) }

  _cset(:backup_name)         { Time.now.utc.strftime("%Y%m%d%H%M%S") }
  _cset(:backup_path)         { File.join(backups_path, backup_name) }

  # backup list and pointers
  _cset(:backups)             { capture("ls -x #{backups_path}").split.sort }
  _cset(:last_backup)         { backups.length > 0 ? File.join(backups_path, backups.last) : nil }
  _cset(:previous_backup)     { backups.length > 1 ? File.join(backups_path, backups[-2]) : nil }

  # backup will be staged locally in this (temporary) location
  _cset(:working_dir)         { File.join('/tmp', backup_name) }

  # switches
  _cset(:autoupdate_config)   { false }
  _cset(:autoprune)           { false }

  namespace :backup do 

    task :tester do
    end   
    
    task :setup, :roles => :backup do
      dirs = [deploy_to, backups_path]
      run "mkdir -p #{dirs.join(' ')}"
      run "chmod #{backup_filemode} #{dirs.join(' ')}"
    end

    task :default do
      update_config if autoupdate_config || ENV['UPDATE_CONFIG']
      prepare
      upload_archives
      cleanup
      prune if autoprune || ENV['PRUNE']
    end

    task :update_config do
      if File.exists?(targets_path)
        g = Git.open(targets_path)
        g.pull
      else
        g = Git.clone(repo, targets_path)
      end
    end

    task :prepare do
      transaction do
        create_directories
        prepare_archives
      end
    end

    task :create_directories, :roles => :backup do
      on_rollback do
        system "rm -rf #{working_dir}"
        run "rm -rf #{backup_path}; true"
      end

      system "mkdir -p #{working_dir}"
      run "mkdir -p #{backup_path}; true"
    end

    task :prepare_archives do
      Dir.glob("#{targets_path}/*.yml") do |file|
        plan_name = File.basename(file).chomp(File.extname(file))
        targets = YAML::load(File.open(file))  

        plan = Capistrano::Backup::Plan.new(plan_name, self)

        to = "#{working_dir}/#{plan_name}"
        logger.important "Running backup plan for `#{plan_name}' targets to #{to}"
        
        # run each backup plan, notify on failure (but continue)
        begin
          plan.archive!(targets, to)
        rescue Capistrano::Error => e
          notify(e)
        end
      end
    end

    task :upload_archives, :roles => :backup do
      Dir.glob("#{working_dir}/*.gz") do |file|
        upload file, "#{backup_path}/#{File.basename(file)}", :mode => backup_filemode
      end 
    end

    task :cleanup do
      logger.info "cleaning up working directory #{working_dir}"
      system "rm -rf #{working_dir}"
    end

    task :prune, :roles => :backup do
      count = fetch(:keep_backups, 5).to_i
      if count >= backups.length
        logger.important "no old backups to prune"
      else
        logger.info "keeping #{count} of #{backups.length} backups"

        directories = (backups - backups.last(count)).map { |backup|
          File.join(backups_path, backup) }.join(" ")

        run "rm -rf #{directories}"
      end
    end
  end
end