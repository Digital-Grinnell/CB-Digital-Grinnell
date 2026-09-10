# frozen_string_literal: true

###############################################################################
# TASK: deploy_branch
#
# Switch to a branch, pull the latest from origin, build for production
# ('rake deploy'), load Azure settings from .env, and upload _site to the
# matching Azure $web destination.
#
# Usage:
#   rake deploy_branch[main]
#   rake deploy_branch[georgia-dentel]
#
# The Azure --destination-path is derived from the branch's _config.yml
# 'baseurl' value: blank baseurl (main) deploys to the $web root; a baseurl
# like "/georgia-dentel" deploys under $web/georgia-dentel/.
###############################################################################

desc 'Switch to a branch, pull, build for production, and deploy to Azure'
task :deploy_branch, [:branch] do |_t, args|
  abort 'Usage: rake deploy_branch[branch-name]' if args.branch.nil? || args.branch.strip.empty?

  branch = args.branch.strip

  # refuse to run with uncommitted local changes, so branch switching can't lose or mix work
  status = `git status --porcelain`.strip
  abort "Working tree has uncommitted changes. Commit or stash them before deploying.\n#{status}" unless status.empty?

  puts "== Fetching origin =="
  system('git', 'fetch', 'origin') or abort 'git fetch failed'

  puts "== Switching to '#{branch}' =="
  system('git', 'checkout', branch) or abort "git checkout #{branch} failed"

  puts "== Pulling latest from origin/#{branch} =="
  system('git', 'pull', '--ff-only', 'origin', branch) or abort 'git pull failed'

  puts '== Building for production (rake deploy) =='
  ENV['JEKYLL_ENV'] = 'production'
  system('bundle', 'exec', 'jekyll', 'build') or abort 'jekyll build failed'

  # derive the Azure destination path from this branch's configured baseurl
  config_text = File.read('_config.yml')
  baseurl_line = config_text.lines.find { |l| l =~ /^baseurl:/ }
  baseurl = baseurl_line ? baseurl_line.sub(/^baseurl:/, '').strip.gsub(/\A["']|["']\z/, '') : ''
  destination_path = baseurl.sub(%r{\A/}, '')

  abort '.env file not found. Copy .env.example to .env and configure Azure settings first.' unless File.exist?('.env')

  # load .env into this process's environment, equivalent to `source .env`
  File.readlines('.env').each do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    next unless line =~ /\Aexport\s+(\w+)=(.*)\z/

    ENV[Regexp.last_match(1)] = Regexp.last_match(2).gsub(/\A["']|["']\z/, '')
  end

  cmd = ['az', 'storage', 'blob', 'upload-batch', '--destination', '$web', '--source', '_site', '--overwrite']
  cmd += ['--destination-path', destination_path] unless destination_path.empty?

  puts '== Ready to deploy =='
  puts "Branch:           #{branch}"
  puts "Azure destination: #{destination_path.empty? ? '$web/ (root site)' : "$web/#{destination_path}/"}"
  puts "WARNING: '#{branch}' is a template branch, not meant for production." if branch == 'collection-template'
  print 'Proceed with upload? [y/N] '
  confirm = $stdin.gets
  abort 'Aborted.' unless confirm && confirm.strip.downcase == 'y'

  system(*cmd) or abort 'az storage blob upload-batch failed'

  puts "== Done. Deployed '#{branch}' to #{destination_path.empty? ? '$web/' : "$web/#{destination_path}/"} =="
end
