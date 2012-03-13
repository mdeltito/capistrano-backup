module Capistrano
  module Backup
    module Plan
      class Base
        attr_reader :configuration
        
        def initialize(config={})
          @configuration = config
        end        
      end
    end
  end
end