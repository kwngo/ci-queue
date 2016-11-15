module CI
  module Queue
    module Redis
      class Base
        def initialize(redis:, build_id:)
          @redis = redis
          @key = "build:#{build_id}"
        end

        def empty?
          size == 0
        end

        def size
          redis.multi do
            redis.llen(key('queue'))
            redis.zcard(key('running'))
          end.inject(:+)
        end

        def to_a
          redis.multi do
            redis.lrange(key('queue'), 0, -1)
            redis.zrange(key('running'), 0, -1)
          end.flatten.reverse
        end

        def progress
          total - size
        end

        def wait_for_master(timeout: 10)
          return true if master?
          (timeout * 10 + 1).to_i.times do
            case master_status
            when 'ready', 'finished'
              return true
            else
              sleep 0.1
            end
          end
          raise LostMaster, "The master worker is still `#{master_status}` after 10 seconds waiting."
        end

        private

        attr_reader :redis

        def key(*args)
          [@key, *args].join(':')
        end

        def master_status
          redis.get(key('master-status'))
        end

        def eval_script(script, *args)
          @scripts_cache ||= {}
          sha = (@scripts_cache[script] ||= redis.script(:load, script))
          redis.evalsha(sha, *args)
        end
      end
    end
  end
end
