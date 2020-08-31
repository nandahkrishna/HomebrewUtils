#!/usr/bin/env ruby
# Author: Nanda H Krishna <nanda.harishankar@gmail.com>
# Retrieve all Homebrew PRs by repository and write to Markdown (GSoC 2020 Report)

require "octokit"

api_key = ENV["GITHUB_API_KEY"]
$client = Octokit::Client.new(login: "nandahkrishna", access_token: api_key)

def get_prs(repo)
  res = $client.search_issues(
    "is:pr author:nandahkrishna repo:Homebrew/#{repo}", per_page: 100
  )
  rels = $client.last_response.rels[:last]
  pages = if rels.nil?
            1
          else
            rels.href.match(/&page=(\d+)/).captures[0].to_i
          end
  File.write(
    $name,
    "\n\n## [Homebrew/#{repo}](https://github.com/Homebrew/#{repo})\n\n",
    mode: "a",
  )
  for i in 1..pages
    res = $client.search_issues(
      "is:pr author:nandahkrishna repo:Homebrew/#{repo}",
      per_page: 100,
      page: i,
    )
    res = res[:items].map { |pr| pr.to_h }
    md = res.map { |pr| "* ##{pr[:number]} - [#{pr[:title]}](#{pr[:html_url]})\n" }
    File.write($name, md.join, mode: "a")
  end
end

# Create Report File
$name = "GSoC_2020_Report.md"
File.write(
  $name,
  "# GSoC 2020 Report" \
  "\n#### Author: [Nanda H Krishna](https://github.com/nandahkrishna)" \
  "\n#### Organisation: [Homebrew](https://github.com/Homebrew)",
)
["brew", "homebrew-core", "homebrew-livecheck"].each do |repo|
  get_prs(repo)
end
