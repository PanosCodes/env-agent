require 'spec_helper'
require_relative '../../lib/env_agent'
require 'tmpdir'

RSpec.describe EnvAgent::CLI do
  let(:tmp) { Dir.mktmpdir }
  let(:sandbox) { Sandbox.new(File.realpath(tmp)) }
  let(:name) { 'design-system' }
  let(:cwd) { sandbox.main }
  let(:checkout) { cwd }
  let(:link) { File.join(checkout, '.env-agent', name) }
  let(:main_dotenv) { File.join(sandbox.main, '.env.agents') }
  let(:elsewhere) { File.join(sandbox.root, 'elsewhere', name) }
  let(:gone) { File.join(sandbox.root, 'gone') }
  let(:no_account) { '~no-such-account-env-agent/dir' }

  before do
    sandbox.build_main!
    FileUtils.mkdir_p(elsewhere)
  end

  after { FileUtils.rm_rf(tmp) }

  shared_examples 'prints no path' do
    it 'prints no path' do
      expect(subject.output).not_to include(tmp)
    end
  end

  shared_examples 'links to' do |label|
    it "links to the directory saved in the #{label}", :aggregate_failures do
      expect(subject.exitstatus).to eq(0)
      expect(File.realpath(link)).to eq(File.realpath(target))
      expect(subject.stdout).to include("#{name}: linked (#{label})")
    end
  end

  describe 'set' do
    subject { sandbox.run(*args, cwd: cwd) }

    let(:args) { ['set', name, elsewhere] }

    it 'saves the directory in the main checkout and links it', :aggregate_failures do
      expect(subject.exitstatus).to eq(0)
      expect(File.read(main_dotenv)).to eq("#{name}=#{elsewhere}\n")
      expect(File.realpath(link)).to eq(File.realpath(elsewhere))
    end

    it_behaves_like 'prints no path'

    it 'keeps its own files out of git', :aggregate_failures do
      expect { subject }.to(change { File.exist?(sandbox.exclude_file) && File.read(sandbox.exclude_file) })
      expect(File.read(sandbox.exclude_file).lines.map(&:chomp)).to include('/.env.agents', '/.env-agent/')
    end

    context 'when run twice' do
      before { sandbox.run(*args) }

      it 'adds nothing to info/exclude the second time' do
        expect { subject }.not_to(change { File.read(sandbox.exclude_file) })
      end
    end

    context 'when run from a linked worktree' do
      let(:cwd) { sandbox.worktree }

      before { sandbox.add_worktree! }

      it 'still writes the main checkout .env.agents', :aggregate_failures do
        expect(subject.exitstatus).to eq(0)
        expect(File.read(main_dotenv)).to eq("#{name}=#{elsewhere}\n")
        expect(File.exist?(File.join(sandbox.worktree, '.env.agents'))).to be(false)
      end
    end

    context 'with an existing name and other lines' do
      let(:other_line) { 'other=/somewhere' }

      before { File.write(main_dotenv, "#{other_line}\n#{name}=/old\n") }

      it 'replaces the name and keeps the other lines' do
        expect { subject }.to change { File.read(main_dotenv) }.to("#{other_line}\n#{name}=#{elsewhere}\n")
      end
    end

    context 'with a directory that has spaces' do
      let(:elsewhere) { File.join(sandbox.root, 'my dirs', name) }

      it 'quotes it and still links it', :aggregate_failures do
        expect(subject.exitstatus).to eq(0)
        expect(File.read(main_dotenv)).to eq("#{name}=\"#{elsewhere}\"\n")
        expect(File.realpath(link)).to eq(File.realpath(elsewhere))
      end
    end

    context 'with a directory that does not exist' do
      let(:args) { ['set', name, gone] }

      it 'saves nothing', :aggregate_failures do
        expect(subject.exitstatus).to eq(1)
        expect(File.exist?(main_dotenv)).to be(false)
      end

      it_behaves_like 'prints no path'
    end

    context 'with a ~name that names no account' do
      let(:args) { ['set', name, no_account] }

      it 'saves nothing and does not echo it', :aggregate_failures do
        expect(subject.exitstatus).to eq(1)
        expect(subject.output).not_to include('no-such-account')
      end
    end

    context 'with an invalid name' do
      let(:args) { ['set', '../escape', elsewhere] }

      it 'exits with a usage error' do
        expect(subject.exitstatus).to eq(2)
      end
    end

    context 'without a directory' do
      subject { sandbox.run('set', name, stdin: "#{elsewhere}\n") }

      it 'reads it from stdin' do
        expect { subject }.to change { File.exist?(main_dotenv) && File.read(main_dotenv) }.to("#{name}=#{elsewhere}\n")
      end

      it_behaves_like 'prints no path'
    end
  end

  describe 'link' do
    subject { sandbox.run('link', cwd: cwd) }

    before { File.write(main_dotenv, "#{name}=#{elsewhere}\n") }

    it_behaves_like 'links to', 'main checkout .env.agents' do
      let(:target) { elsewhere }
    end
    it_behaves_like 'prints no path'

    context 'when run from a linked worktree' do
      let(:cwd) { sandbox.worktree }

      before { sandbox.add_worktree! }

      it_behaves_like 'links to', 'main checkout .env.agents' do
        let(:target) { elsewhere }
      end
      it_behaves_like 'prints no path'

      context 'with its own .env.agents' do
        let(:override) { File.join(sandbox.root, 'override', name) }

        before do
          FileUtils.mkdir_p(override)
          File.write(File.join(sandbox.worktree, '.env.agents'), "#{name}=#{override}\n")
        end

        it_behaves_like 'links to', 'worktree .env.agents' do
          let(:target) { override }
        end
      end

      context 'with its own .env.agents pointing at a missing directory' do
        before { File.write(File.join(sandbox.worktree, '.env.agents'), "#{name}=#{gone}\n") }

        it_behaves_like 'links to', 'main checkout .env.agents' do
          let(:target) { elsewhere }
        end
      end
    end

    context 'with the name also in the process env' do
      subject { sandbox.run('link', env: { name => gone }) }

      it_behaves_like 'links to', 'main checkout .env.agents' do
        let(:target) { elsewhere }
      end
    end

    context 'with an existing stale link' do
      before do
        FileUtils.mkdir_p([gone, File.dirname(link)])
        File.symlink(gone, link)
      end

      it_behaves_like 'links to', 'main checkout .env.agents' do
        let(:target) { elsewhere }
      end
    end

    context 'when the saved directory is gone' do
      before { FileUtils.rm_rf(elsewhere) }

      it 'fails, removes the link and says how to fix it', :aggregate_failures do
        expect(subject.exitstatus).to eq(1)
        expect(File.symlink?(link)).to be(false)
        expect(subject.stderr).to include("env-agent set #{name}", 'env-agent agent')
      end

      it_behaves_like 'prints no path'
    end

    context 'with a saved ~name that names no account' do
      before { File.write(main_dotenv, "#{name}=#{no_account}\n") }

      it 'reports it as not found without echoing it', :aggregate_failures do
        expect(subject.exitstatus).to eq(1)
        expect(subject.stderr).to include("#{name}: not linked (main checkout .env.agents: directory missing)")
        expect(subject.output).not_to include('no-such-account')
      end
    end

    context 'when nothing is set' do
      before { FileUtils.rm_f(main_dotenv) }

      it 'says so and succeeds', :aggregate_failures do
        expect(subject.exitstatus).to eq(0)
        expect(subject.stdout).to include('nothing set in .env.agents')
      end
    end
  end
end
