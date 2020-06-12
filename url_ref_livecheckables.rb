#!/usr/bin/env ruby
# frozen-string-literal: true

# Author: Nanda H Krishna <nanda.harishankar@gmail.com>
# Check if Livecheckable URLs in homebrew-livecheck reuse any Formula
# URLs such as head, stable, devel or homepage

require "json"
require "ruby-progressbar"

# Absolute path to Livecheckables
livecheckables_dir = `echo $(brew --repo homebrew/livecheck)`.strip
livecheckables_dir += "/Livecheckables/"

# If command-line args are given, check only those Formulae
# Else check all Formulae
formulae = if ARGV.empty?
             Dir[livecheckables_dir + "*.rb"]
           else
             ARGV.map { |s| livecheckables_dir + s + ".rb" }
           end
formulae = formulae.sort

# Progress bar
bar = ProgressBar.create(
  title: "Checking",
  total: formulae.length,
  format: "\e[0;34m%t\e[0m: [%B] \e[0;34m%c/%C\e[0m"
)

# Total changes to be made
total_changes = 0

formulae.each do |formula|
  name = formula.split("/")[-1]
  # If non-existent, notify
  if !File.exist?(formula)
    bar.increment
    bar.log "\e[0;34m#{name}:\e[0m \e[0;31mdoes not exist!\e[0m"
  # Process existing Formulae
  else
    # Read the Livecheckable and get the url
    livecheckable = File.read(formula).split("\n")
    index = livecheckable.find_index do |s|
      s.start_with? "    url "
    end
    already_ref = livecheckable.find_index do |s|
      s.start_with? "    url :"
    end
    if index.nil?
      bar.log "\e[0;34m#{name}:\e[0m \e[0;33mno url!\e[0m"
      bar.increment
      next
    elsif !already_ref.nil?
      bar.log "\e[0;34m#{name}:\e[0m \e[0;33malready references a URL!\e[0m"
      bar.increment
      next
    end
    livecheck_url = livecheckable[index].gsub("    url ", "")
                                        .gsub('"', "").strip
    # Remove the .rb extension
    formula_name = name[0..-4]
    # Load the Formula using brew ruby and get all urls
    # Result is a Hash containing possible reference urls
    urls = JSON.parse(`brew ruby -e 'f = "#{formula_name}".f; \
           urls = {}; \
           if f.head then; urls["head"] = f.head.url; end; \
           if f.stable then; urls["stable"] = f.stable.url; end; \
           if f.devel then; urls["devel"] = f.devel.url; end; \
           if f.homepage then; urls["homepage"] = f.homepage; end; \
           puts urls;'`.gsub("=>", ":"), symbolize_names: true)
    # Check if any url can be referenced, and modify the Livecheckable
    change = false
    urls.each do |ref, url|
      next unless (livecheck_url == url) || (livecheck_url == url + "/") ||
                  (livecheck_url + "/" == url) ||
                  (livecheck_url.gsub(%r{\.git/?$}, "") == url) ||
                  (livecheck_url.gsub(%r{\.git/?$}, "/") == url)

      livecheckable[index] = "    url :" + ref.to_s
      File.write(formula, livecheckable.join("\n") + "\n")
      bar.log "\e[0;34m#{name}:\e[0m \e[0;32musing :#{ref}!\e[0m"
      change = true
      total_changes += 1
      break
    end
    bar.log "\e[0;34m#{name}:\e[0m \e[0;33mno changes!\e[0m" unless change
    bar.increment
  end
end

puts "\e[0;34mTotal changes:\e[0m #{total_changes}"
puts "\e[0;31mDo a full livecheck run to ensure these changes work!\e[0m"
