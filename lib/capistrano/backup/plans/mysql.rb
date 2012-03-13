module Capistrano
  module Backup
    module Plan

      # Plans should extend at least the base class
      class Mysql < Base

        # Plans should inplement an archive! method with this signature
        #  targets => YAML array of targets
        #  to => output directory 
        def archive!(targets, to)
          targets[mysql_target_entities].each do |target|

            cmd = []
            cmd << "#{mysqldump_bin}"
           
            cmd << "-u#{target['user']}" unless target['user'].nil?
            cmd << "-p#{target['password']}" unless target['password'].nil?
           
            if target['db'].nil? || target['db'] == 'all'
              cmd << '--all-databases'
            else
              cmd << "#{target['db']}"                
            end

            cmd << "#{target['tables']}" unless target['tables'].nil?
            cmd << "| #{gzip_bin} -c > #{to}.sql.gz"

            system(cmd.join(' '))

            unless $? == 0
              raise Capistrano::Error, "shell command failed with return code #{$?}"
            end
          end
        end

        private
          def mysql_target_entities
            @mysql_target_entities ||= @configuration.fetch(:mysql_target_entities, 'servers')
          end

          def mysqldump_bin
            @mysqldump_bin ||= @configuration.fetch(:mysqldump_bin, `which mysqldump`.strip!)
          end

          def mysqldump_port
            @port ||= @configuration.fetch(:mysqldump_port, 3306)
          end

          def gzip_bin
            @gzip_bin ||= @configuration.fetch(:gzip_bin, `which gzip`.strip!)
          end

      end
    end
  end
end