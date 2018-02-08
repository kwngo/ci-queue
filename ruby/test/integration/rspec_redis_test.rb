require 'test_helper'

module Integration
  class RSpecRedisTest < Minitest::Test
    include OutputTestHelpers

    def setup
      @redis_url = "redis://#{ENV.fetch('REDIS_HOST', 'localhost')}/7"
      @redis = Redis.new(url: @redis_url)
      @redis.flushdb
      @exe = File.expand_path('../../../exe/rspec-queue', __FILE__)
    end

    def test_redis_runner
      out, err = capture_subprocess_io do
        system(
          { 'BUILDKITE' => '1', 'BUILDKITE_COMMIT' => 'aaaaaaaaaaaaa' },
          @exe,
          '--queue', @redis_url,
          '--seed', '123',
          '--build', '1',
          '--worker', '1',
          '--timeout', '1',
          '--max-requeues', '1',
          '--requeue-tolerance', '1',
          chdir: 'test/fixtures/',
        )
      end

      assert_empty err
      expected_output = strip_heredoc <<-EOS

        Randomized with seed 123
        ..*.

        Pending: (Failures listed here are expected and do not affect your suite's status)

          1) Object doesn't work on first try
             # The example failed, but another attempt will be done to rule out flakiness
             # ./spec/dummy_spec.rb:6

        Finished in X.XXXXX seconds (files took X.XXXXX seconds to load)
        4 examples, 0 failures, 1 pending

        Randomized with seed 123

      EOS

      assert_equal expected_output, normalize(out)
    end

    def test_report
      out, err = capture_subprocess_io do
        system(
          { 'BUILDKITE' => '1', 'BUILDKITE_COMMIT' => 'aaaaaaaaaaaaa' },
          @exe,
          '--queue', @redis_url,
          '--seed', '123',
          '--build', '1',
          '--worker', '1',
          '--timeout', '1',
          '--max-requeues', '0',
          '--requeue-tolerance', '0',
          chdir: 'test/fixtures/',
        )
      end

      assert_empty err
      expected_output = strip_heredoc <<-EOS
        
        Randomized with seed 123
        ..F

        Failures:

          1) Object doesn't work on first try
             Failure/Error: expect(1 + 1).to be == 42

               expected: == 42
                    got:    2
             # ./spec/dummy_spec.rb:11:in `block (2 levels) in <top (required)>'

        Finished in X.XXXXX seconds (files took X.XXXXX seconds to load)
        3 examples, 1 failure

        Failed examples:

        rspec ./spec/dummy_spec.rb:6 # Object doesn't work on first try

        Randomized with seed 123

      EOS

      assert_equal expected_output, normalize(out)

      out, err = capture_subprocess_io do
        system(
          { 'BUILDKITE' => '1', 'BUILDKITE_COMMIT' => 'aaaaaaaaaaaaa' },
          @exe,
          '--queue', @redis_url,
          '--build', '1',
          '--report',
          '--timeout', '5',
          chdir: 'test/fixtures/',
        )
      end

      assert_empty err
      expected_output = strip_heredoc <<-EOS
        --- Waiting for workers to complete
        +++ 1 error found

          Object doesn't work on first try
          Failure/Error: expect(1 + 1).to be == 42

            expected: == 42
                 got:    2
          # ./spec/dummy_spec.rb:11:in `block (2 levels) in <top (required)>'

        rspec ./spec/dummy_spec.rb:6 # Object doesn't work on first try
      EOS

      assert_equal expected_output, normalize(out)
    end

    private

    def normalize(output)
      rewrite_paths(freeze_timing(decolorize_output(output)))
    end
  end
end
