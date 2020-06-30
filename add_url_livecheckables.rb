#!/usr/bin/env ruby
# frozen-string-literal: true

# Author: Nanda H Krishna <nanda.harishankar@gmail.com>
# Reference the Formula URL used by each Livecheckable without
# an explicit url

require "json"
require "ruby-progressbar"

# Absolute path to Livecheckables
livecheckables_dir = `echo $(brew --repo homebrew/livecheck)`.strip
livecheckables_dir += "/Livecheckables/"

# If command-line args are given, check only those Formulae
# Else check all Formulae without a url that aren't skipped
formulae = if ARGV.empty?
             `grep -L 'url [":]' $(grep -L 'skip ' #{livecheckables_dir}*)` \
               .split
           else
             ARGV.map { |s| livecheckables_dir + s + ".rb" }
           end
formulae = formulae.sort

# Progress bar
bar = ProgressBar.create(
  title: "Updating",
  total: formulae.length,
  format: "\e[0;34m%t\e[0m: [%B] \e[0;34m%c/%C\e[0m"
)

formulae.each do |formula|
  name = formula.split("/")[-1]
  # If non-existent, notify
  if !File.exist?(formula)
    bar.increment
    bar.log "\e[0;34m#{name}:\e[0m \e[0;31mdoes not exist!\e[0m"
  # Ignore biosig, darkice and x3270
  elsif ["biosig.rb", "darkice.rb", "x3270.rb", ].include? name
    bar.increment
    bar.log "\e[0;34m#{name}:\e[0m \e[0;33mignored!\e[0m"
  # Process existing Formulae
  else
    # Read the Livecheckable
    livecheckable = File.read(formula).split("\n")
    url_exists = livecheckable.find_index do |s|
      s.start_with? "    url "
    end
    unless url_exists.nil?
      bar.log "\e[0;34m#{name}:\e[0m \e[0;33malready has a URL!\e[0m"
      bar.increment
      next
    end
    skip_exists = livecheckable.find_index do |s|
      s.start_with? "    skip "
    end
    unless skip_exists.nil?
      bar.log "\e[0;34m#{name}:\e[0m \e[0;33mskipped!\e[0m"
      bar.increment
      next
    end
    # Get the index to insert the url reference
    url_index = livecheckable.find_index do |s|
      s.start_with? "  livecheck do"
    end + 1
    # Remove the .rb extension
    formula_name = name[0..-4]
    # Get the url used by livecheck
    livecheck_url = JSON.parse(`brew livecheck --json -v #{formula_name}`)
    livecheck_url = livecheck_url[0]["meta"]["url"]["original"]
    # Load the Formula using brew ruby and get all urls
    # Result is a Hash containing all possible urls
    urls = JSON.parse(`brew ruby -e 'f = "#{formula_name}".f; \
           urls = {}; \
           if f.head then; urls["head"] = f.head.url; end; \
           if f.stable then; urls["stable"] = f.stable.url; end; \
           if f.devel then; urls["devel"] = f.devel.url; end; \
           if f.homepage then; urls["homepage"] = f.homepage; end; \
           puts urls;'`.gsub("=>", ":"), symbolize_names: true)
    urls.each do |ref, url|
      next if livecheck_url != url

      livecheckable.insert(url_index, "    url :" + ref.to_s)
      File.write(formula, livecheckable.join("\n") + "\n")
      bar.log "\e[0;34m#{name}:\e[0m \e[0;32musing :#{ref}!\e[0m"
      break
    end
    bar.increment
  end
end

shortstat = `cd #{livecheckables_dir}; git diff --shortstat`
puts "\e[0;34mgit diff --shortstat\e[0m#{shortstat}"
puts "\e[0;31mDo a full livecheck run to ensure these changes work!\e[0m"
