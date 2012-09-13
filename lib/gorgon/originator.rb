require 'gorgon/originator_protocol'
require 'gorgon/configuration'
require 'gorgon/job_state'
require 'gorgon/progress_bar_view'
require 'gorgon/originator_logger'

require 'awesome_print'

class Originator
  include Configuration

  def initialize
    @configuration = nil
  end

  def originate
    begin
      Signal.trap("INT") { ctrl_c }
      Signal.trap("TERM") { ctrl_c }

      publish
      @logger.log "Originator finished successfully"
    rescue Exception
      @logger.log_error "Unhandled Exception!"

      puts "Unhandled exception in originator:"
      puts $!.message
      puts $!.backtrace.join("\n")
      puts "----------------------------------"
      puts "Now attempting to cancel the job."
      cancel_job
    end
  end

  def ctrl_c
    puts "\nCtrl-C received! Just wait a moment while I clean up..."
    cancel_job
  end

  def cancel_job
    @protocol.cancel_job
    @job_state.cancel

    @protocol.disconnect
  end

  def publish
    @logger = OriginatorLogger.new configuration[:originator_log_file]
    @protocol = OriginatorProtocol.new @logger

    EventMachine.run do
      @logger.log "Connecting..."
      @protocol.connect connection_information, :on_closed => method(:on_disconnect)

      @logger.log "Publishing files..."
      @protocol.publish_files files
      create_job_state_and_observers

      @logger.log "Publishing Job..."
      @protocol.publish_job job_definition
      @logger.log "Job Published"

      @protocol.receive_payloads do |payload|
        handle_reply(payload)
      end
    end
  end

  def cleanup_if_job_complete
    if @job_state.is_job_complete?
      @logger.log "Job is done"
      @protocol.disconnect
    end
  end

  def handle_reply(payload)
    payload = Yajl::Parser.new(:symbolize_keys => true).parse(payload)

    # at some point this will probably need to be fancy polymorphic type based responses, or at least a nice switch statement
    if payload[:action] == "finish"
      @job_state.file_finished payload
    elsif payload[:action] == "start"
      @job_state.file_started payload
    end
    @logger.log_message payload
    # Uncomment this to see each message received by originator
    # ap payload

    cleanup_if_job_complete
  end

  def create_job_state_and_observers
    @job_state = JobState.new files.count
    @progress_bar_view = ProgressBarView.new @job_state
    @progress_bar_view.show
  end

  def on_disconnect
    EventMachine.stop
  end

  def connection_information
    configuration[:connection]
  end

  def files
    @files ||= configuration[:files].reduce([]) do |memo, obj|
      memo.concat(Dir[obj])
    end.uniq
  end

  def job_definition
    JobDefinition.new(@configuration[:job])
  end

  def configuration
    @configuration ||= load_configuration_from_file("gorgon.json")
  end
end
