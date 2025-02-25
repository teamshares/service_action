# frozen_string_literal: true

module ServiceAction
  module Enqueueable
    def self.included(base)
      base.class_eval do
        begin
          require "sidekiq"
          include Sidekiq::Job
        rescue LoadError
          puts "Sidekiq not available -- skipping Enqueueable"
          return
        end

        define_method(:perform) do |*args|
          context = args.first
          bang = args.size > 1 ? args.last : false

          if bang
            self.class.call!(context)
          else
            self.class.call(context)
          end
        end

        def self.enqueue(context = {})
          perform_async(process_context_to_sidekiq_args(context))
        end

        def self.enqueue!(context = {})
          perform_async(process_context_to_sidekiq_args(context), true)
        end

        def self.queue_options(opts)
          opts = opts.transform_keys(&:to_s)
          self.sidekiq_options_hash = get_sidekiq_options.merge(opts)
        end

        private

        def self.process_context_to_sidekiq_args(context)
          client = Sidekiq::Client.new

          context.stringify_keys.tap do |args|
            if client.send(:json_unsafe?, args).present?
              raise ArgumentError, "Cannot pass non-JSON-serializable objects to Sidekiq. Make sure all objects in the context are serializable."
            end
          end
        end
      end
    end
  end
end
