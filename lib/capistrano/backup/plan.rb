module Capistrano
  module Backup
    module Plan
      require 'capistrano/backup/plans/base'

      def self.new(plan, config={})
        plan_file = "capistrano/backup/plans/#{plan}"
        require plan_file
        
        plan_const = plan.to_s.capitalize.gsub(/_(.)/) { $1.upcase }
        if const_defined?(plan_const)
          const_get(plan_const).new(config)
        else
          raise Capistrano::Error, "could not find `#{name}::#{plan_const}' in `#{plan_file}'"
        end
      rescue LoadError
        raise Capistrano::Error, "could not find any plan named `#{plan}'"
      end  		
    end	
	end
end

