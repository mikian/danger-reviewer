require 'net/http'
require 'uri'
require 'json'
require_relative './github'

module Danger
  class DangerReviewer < Plugin
    def assign(team, max_reviewers = 2, user_blacklist = [])
      current = current_reviewers

      # Check if we already have enough reviewers
      return if current.count >= max_reviewers

      authors = find_authors
      members = team_members(team)
      reviewers = find_reviewers((authors & members), members, user_blacklist, (max_reviewers - current.count))

      request_reviews(reviewers)
    end

    def request_reviews(reviewers)
      owner, repo = env.ci_source.repo_slug.split('/')

      uri = URI.parse("https://api.github.com/repos/#{owner}/#{repo}/pulls/#{github.pr_json[:number]}/requested_reviewers")
      header = {'Content-Type': 'text/json', 'Authorization': "token #{ENV['DANGER_GITHUB_API_TOKEN']}" }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = {'reviewers': reviewers}.to_json

      # Send the request
      response = http.request(request)
      response.status == 201
    end

    def find_authors
      owner, repo = env.ci_source.repo_slug.split('/')
      branch = github.branch_for_head

      users = Hash.new(0)

      git.modified_files.each do |file|
        result = GitHub::Client.query(GitHub::BlameQuery, variables: { repository: repo, owner: owner, ref: branch, file: file })
        next if result.data.repository.ref.nil?
        result.data.repository.ref.target.blame.ranges.each do |range|
          lines = (range.ending_line - range.starting_line) + 1
          users[range.commit.author.user.login] += lines unless range.commit.author.user.nil?
        end
      end

      users.keys
    end

    def find_reviewers(authors, members, user_blacklist, max_reviewers)
      user_blacklist << github.pr_author

      reviewers = []

      authors = authors - user_blacklist
      authors = authors.sort_by { |_, value| value }.reverse

      reviewers += authors[0...max_reviewers]

      if reviewers.count < max_reviewers
        reviewers += (members - reviewers).sample(max_reviewers - reviewers.count)
      end

      reviewers
    end

    def current_reviewers
      owner, repo = env.ci_source.repo_slug.split('/')

      result = GitHub::Client.query(GitHub::ReviewerQuery, variables: { repo: repo, owner: owner, number: github.pr_json[:number] })
      result.data.repository.pull_request.review_requests.edges.map { |edge| edge.node.reviewer.login }
    end

    def team_members(team)
      owner, repo = env.ci_source.repo_slug.split('/')
      result = GitHub::Client.query(GitHub::MemberQuery, variables: { organization: owner, team: team})
      result.data.organization.team.members.edges.map { |edge| edge.node.login }
    end
  end
end
