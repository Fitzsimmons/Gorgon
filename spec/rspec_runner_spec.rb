require 'gorgon/rspec_runner'

describe RspecRunner do

  subject {RspecRunner}
  it {should respond_to(:run_file).with(1).argument}
  it {should respond_to(:runner).with(0).argument}

  describe "#run_file" do
    before do
      RSpec::Core::Runner.stub(:run)
    end

    it "uses Rspec runner to run filename and uses the correct options" do
      RSpec::Core::Runner.should_receive(:run).with(["-f",
                                                     "RSpec::Core::Formatters::GorgonRspecFormatter",
                                                     "file"], anything, anything)
      RspecRunner.run_file "file"
    end

    it "passes StringIO's (or something similar) to rspec runner" do
      RSpec::Core::Runner.should_receive(:run).with(anything,
                                                    duck_type(:read, :write, :close),
                                                    duck_type(:read, :write, :close))
      RspecRunner.run_file "file"
    end

    it "parses the output of the Runner and returns it"
  end
end