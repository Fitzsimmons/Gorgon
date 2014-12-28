require 'gorgon/runtime_file_reader'
require 'yajl'

describe RuntimeFileReader do

  describe "#old_files" do
    let(:runtime_filename){ "runtime_file.json" }

    it "should read runtime_file" do
      File.stub(:file?).and_return(true)
      runtime_file_reader = RuntimeFileReader.new(runtime_filename)
      File.should_receive(:open).with(runtime_filename, 'r')
      runtime_file_reader.old_files
    end

    it "should return empty array if runtime_file is invalid" do
      File.should_receive(:file?).and_return(false)
      runtime_file_reader = RuntimeFileReader.new(runtime_filename)
      File.should_not_receive(:open)
      runtime_file_reader.old_files
    end
  end


  describe "#sorted_files" do
    let (:old_files){ [ "old_a.rb", "old_b.rb", "old_c.rb"] }

    before do
      @runtime_file_reader = RuntimeFileReader.new "runtime_file.json"
      @runtime_file_reader.stub(:old_files).and_return old_files
    end

    it "should include new files at the end" do
      current_spec_files = ["new_a.rb", "old_b.rb", "old_a.rb", "new_b.rb", "old_c.rb"]
      sorted_files = @runtime_file_reader.sorted_files(current_spec_files)
      expect(sorted_files.first(sorted_files.size-2)).to eq(old_files)
      expect(sorted_files.last(2)).to eq(["new_a.rb", "new_b.rb"])
    end

    it "should remove old files that are not in current files" do
      current_spec_files = ["new_a.rb", "old_a.rb", "old_c.rb"]
      sorted_files = @runtime_file_reader.sorted_files(current_spec_files)
      expect(sorted_files.first(2)).to eq(["old_a.rb", "old_c.rb"])
      expect(sorted_files.last(1)).to eq(["new_a.rb"])
    end
  end

end
