require "rspec"

module RSpec
  class SleepStudy
    RSpec::Core::Formatters.register self, :dump_summary, :example_started,
                                     :example_failed, :example_passed, :example_pending

    def initialize(output)
      @output = output
      @sleepers = []
      @tracers = [
        TracePoint.new(:c_call) { |tp| start_sleep if tp.method_id == :sleep },
        TracePoint.new(:c_return) { |tp| end_sleep if tp.method_id == :sleep }
      ]
    end

    def example_started(_notification)
      @total_time_slept = 0
      @sleep_starts = []
      @tracers.each(&:enable)
    end

    def example_failed(notification)
      @tracers.each(&:disable)
      record_time_slept(notification)
    end

    def example_passed(notification)
      @tracers.each(&:disable)
      record_time_slept(notification)
    end

    def example_pending(notification)
      @tracers.each(&:disable)
      record_time_slept(notification)
    end

    def dump_summary(_notification)
      return unless sleepers_to_report.any?

      @output << "\nThe following examples spent the most time in `sleep`:\n"

      sleepers_to_report.each do |slept, example|
        @output << "  #{slept.round(2)} seconds: #{example.location}\n"
      end

      @output << "\n"
    end

    private

    def start_sleep
      @sleep_starts << Time.now.to_f
    end

    def end_sleep
      @total_time_slept += Time.now.to_f - @sleep_starts.pop if @sleep_starts.any?
    end

    def sleepers_to_report
      @sleepers.sort_by { |s| -s[0] }[0, 10]
    end

    def record_time_slept(notification)
      return if @total_time_slept.zero?
      @sleepers << [@total_time_slept, notification.example]
    end
  end
end
