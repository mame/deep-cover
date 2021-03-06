require "spec_helper"

RSpec::Matchers.define :run_successfully do
  match do |path|
    reader, writer = IO.pipe
    error_r, error_w = IO.pipe
    options = {in: File::NULL, out: writer, err: error_w}

    pid = spawn('ruby', "spec/full_usage/#{path}", options)
    writer.close
    error_w.close
    @output = reader.read.chomp
    @errors = error_r.read.chomp
    Process.wait(pid)
    @exit_code = $?.exitstatus
    reader.close
    @ouput_ok = @expected_output.nil? || @expected_output == @output

    @exit_code == 0 && @ouput_ok && (@errors == '' || RUBY_PLATFORM == 'java')
  end

  chain :and_output do |output|
    @expected_output = output
  end

  failure_message do
    [
      ("expected output '#{@expected_output}', got '#{@output}'" unless @ouput_ok),
      ("expected exit code 0, got #{@exit_code}" if @exit_code != 0),
      ("expected no errors, got '#{@errors}'" unless @errors.empty?),
    ].compact.join(' and ')
  end
end

RSpec.describe 'DeepCover usage' do
  it { 'simple/simple.rb'.should run_successfully.and_output('Done') }
  it { 'with_configure/test.rb'.should run_successfully.and_output('[1, 0, 2, 0, nil, 2, nil, nil]') }
end
