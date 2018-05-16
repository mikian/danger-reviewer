require 'graphql/client'
require 'graphql/client/http'

module GitHub
  HTTP = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
    def headers(_context)
      { 'Authorization' => "bearer #{ENV['DANGER_GITHUB_API_TOKEN']}" }
    end
  end

  Schema = GraphQL::Client.load_schema(File.expand_path('../../data/schema.json', __dir__))

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

  BlameQuery = GitHub::Client.parse <<-'GRAPHQL'
    query($repository:String!, $owner:String!, $ref:String!, $file:String!) {
      # repository name/owner
      repository(name: $repository, owner: $owner) {
        # branch name
        ref(qualifiedName: $ref) {
          target {
            # cast Target to a Commit
            ... on Commit {
              # full repo-relative path to blame file
              blame(path: $file) {
                ranges {
                  commit {
                    author {
                      user {
                        login
                      }
                    }
                  }
                  startingLine
                  endingLine
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  MemberQuery = GitHub::Client.parse <<-'GRAPHQL'
    query($organization:String!, $team:String!) {
      organization(login: $organization) {
        team(slug: $team) {
          members(first: 100) {
            edges {
              node {
                login
              }
            }
          }
        }
      }
    }
  GRAPHQL

  ReviewerQuery = GitHub::Client.parse <<-'GRAPHQL'
    query($owner:String!, $repo:String!, $number:Int!) {
      repository(name: $repo, owner: $owner) {
        pullRequest(number: $number) {
          reviewRequests(first: 10) {
            edges {
              node {
                reviewer {
                  login
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL
end
