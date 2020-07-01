#!/usr/bin/env ruby
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative "./lib/stations_human_diff"

SHD::Logger.info "Veryfing pull requests..."

SHD::EnvironmentChecker.check!

client = SHD::GithubClient.generate
repository = ENV.fetch("GITHUB_REPOSITORY")
pull_requests = client.pull_requests(repository, state: 'open')

pull_requests.each do |pull_request|
  SHD::Logger.info "Veryfing pull request ##{pull_request['number']}..."

  own_comments = SHD::GithubClient.own_comments(client: client, pull: pull_request)
  last_comment = own_comments.last

  commits = SHD::GithubClient.commits(client: client, pull: pull_request)
  last_commit = commits.last

  if last_comment.nil? || last_commit.commit.committer.date > last_comment.updated_at
    SHD::GithubClient.remove_old_comments!(
      client:   client,
      pull:     pull_request,
      comments: own_comments,
    )

    ## Diffing stations..
    report = SHD::DiffAnalyzer.new(
      base: pull_request["base"],
      head: pull_request["head"],
    ).run

    formatted_report = SHD::ReportFormatter.run(report)
    formatted_report = formatted_report.empty? ? 'No changes' : formatted_report

    SHD::GithubClient.post_comment!(
      client: client,
      pull:   pull_request,
      body:   formatted_report,
    )
  end
end

SHD::Logger.info "Done."
