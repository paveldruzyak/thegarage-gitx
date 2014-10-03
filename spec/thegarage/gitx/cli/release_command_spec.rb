require 'spec_helper'
require 'thegarage/gitx/cli/release_command'

describe Thegarage::Gitx::Cli::ReleaseCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::ReleaseCommand.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#release' do
    context 'when user rejects release' do
      before do
        expect(cli).to receive(:yes?).and_return(false)
        expect(cli).to_not receive(:run_cmd)

        cli.release
      end
      it 'only runs update commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release and pull request exists' do
      let(:authorization_token) { '123123' }
      before do
        expect(cli).to receive(:invoke_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update)
        expect(cli).to receive(:invoke_command).with(Thegarage::Gitx::Cli::IntegrateCommand, :integrate, 'staging')
        expect(cli).to receive(:invoke_command).with(Thegarage::Gitx::Cli::CleanupCommand, :cleanup)

        expect(cli).to receive(:yes?).and_return(true)
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(cli).to receive(:run_cmd).with("git checkout master").ordered
        expect(cli).to receive(:run_cmd).with("git pull origin master").ordered
        expect(cli).to receive(:run_cmd).with("git merge --no-ff feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered

        VCR.use_cassette('pull_request_does_exist') do
          cli.release
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release and pull request does not exist' do
      let(:authorization_token) { '123123' }
      let(:new_pull_request) do
        {
          html_url: "https://path/to/html/pull/request",
          issue_url: "https://api/path/to/issue/url",
          number: 10,
          head: {
            ref: "branch_name"
          }
        }
      end
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        allow(cli).to receive(:ask_editor).and_return('description')

        expect(cli).to receive(:invoke_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update).twice
        expect(cli).to receive(:invoke_command).with(Thegarage::Gitx::Cli::IntegrateCommand, :integrate, 'staging')
        expect(cli).to receive(:invoke_command).with(Thegarage::Gitx::Cli::CleanupCommand, :cleanup)

        expect(cli).to receive(:yes?).and_return(true)

        expect(cli).to receive(:run_cmd).with("git log master...feature-branch --no-merges --pretty=format:'* %s%n%b'").and_return("2013-01-01 did some stuff").ordered
        expect(cli).to receive(:run_cmd).with("git checkout master").ordered
        expect(cli).to receive(:run_cmd).with("git pull origin master").ordered
        expect(cli).to receive(:run_cmd).with("git merge --no-ff feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered

        stub_request(:post, 'https://api.github.com/repos/thegarage/thegarage-gitx/pulls').to_return(:status => 201, :body => new_pull_request.to_json, :headers => {'Content-Type' => 'application/json'})
        VCR.use_cassette('pull_request_does_not_exist') do
          cli.release
        end
      end
      it 'creates pull request on github' do
        should meet_expectations
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
  end
end
