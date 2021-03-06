module ScoutApm
  module LayerConverters
    class RequestQueueTimeConverter < ConverterBase

      HEADERS = %w(X-Queue-Start X-Request-Start X-QUEUE-START X-REQUEST-START x-queue-start x-request-start)

      def headers
        request.headers
      end

      def record!
        return unless request.web?

        return unless headers

        Rails.logger.info("===============================================================")
        Rails.logger.info("BEGIN DEBUG")
        raw_start = locate_timestamp
        return unless raw_start
        Rails.logger.info("Raw start: #{raw_start.to_f}")

        parsed_start = parse(raw_start)
        Rails.logger.info("Parsed start: #{parsed_start.to_f}")
        return unless parsed_start

        request_start = root_layer.start_time
        Rails.logger.info("Request start: #{request_start.to_f}")
        queue_time = (request_start - parsed_start).to_f
        Rails.logger.info("Queue time: #{queue_time}")
        Rails.logger.info("END DEBUG")
        Rails.logger.info("===============================================================")

        # If we end up with a negative value, just bail out and don't report anything
        return if queue_time < 0

        meta = MetricMeta.new("QueueTime/Request", {:scope => scope_layer.legacy_metric_name})
        stat = MetricStats.new(true)
        stat.update!(queue_time)

        @store.track!({ meta => stat })
      end

      private

      # Looks through the possible headers with this data, and extracts the raw
      # value of the header
      # Returns nil if not found
      def locate_timestamp
        return nil unless headers

        header = HEADERS.find { |candidate| headers[candidate] }
        if header
          data = headers[header]
          data.to_s.gsub(/(t=|\.)/, '')
        else
          nil
        end
      end

      # Returns a timestamp in fractional seconds since epoch
      def parse(time_string)
        Time.at("#{time_string[0,10]}.#{time_string[10,13]}".to_f)
      end
    end
  end
end
