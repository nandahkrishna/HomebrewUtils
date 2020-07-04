#!/usr/bin/env ruby
# frozen-string-literal: true

# Author: Nanda H Krishna <nanda.harishankar@gmail.com>
# Change the extension in the Livecheckables' regex as follows:
# \.tar, \.tar\.gz, \.tgz, etc. -> \.t
# \.z -> \.zip
# \.j -> \.jar

require "json"
require "ruby-progressbar"

# Absolute path to Livecheckables
livecheckables_dir = `echo $(brew --repo homebrew/livecheck)`.strip
livecheckables_dir += "/Livecheckables/"

# If command-line args are given, check only those Livecheckables
# Else check all Livecheckables
formulae = if ARGV.empty?
             Dir[livecheckables_dir + "*.rb"]
           else
             ARGV.map { |s| livecheckables_dir + s + ".rb" }
           end
formulae = formulae.sort
zip_formulae = `grep "regex.*\\.z[^a-z]" #{livecheckables_dir}* \
                | sed -e "s/:.*//"` \
               .split.sort
jar_formulae = `grep "regex.*\\.j[^a-z]" #{livecheckables_dir}* \
                | sed -e "s/:.*//"` \
               .split.sort
tar_formulae = `grep "regex.*\\.t\\([Zabglpz]\\|xz\\)" #{livecheckables_dir}* \
                | sed -e "s/:.*//"` \
               .split.sort

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
  # If the Livecheckable doesn't need updation, notify
  elsif !(zip_formulae | jar_formulae | tar_formulae).include? formula
    bar.increment
    bar.log "\e[0;34m#{name}:\e[0m \e[0;33mno updation required!\e[0m"
  # Process existing Livecheckables in need of changes
  else
    # Read the Livecheckable
    livecheckable = File.read(formula).split("\n")
    regex_index = livecheckable.find_index do |s|
      s.start_with? "    regex("
    end
    # Remove the .rb extension
    formula_name = name[0..-4]
    # Livecheck output before updation
    livecheck_pre = JSON.parse(`brew livecheck --json #{formula_name}`)
    # Update the Livecheckable
    old_livecheckable = []
    livecheckable.each { |e| old_livecheckable << e.dup }
    livecheckable[regex_index].gsub!(/\\?\.z/, "\\.zip")
    livecheckable[regex_index].gsub!(/\\?\.j/, "\\.jar")
    livecheckable[regex_index].gsub!(
      /\\?\.t(?:ar)?(?:\\?\.?[2A-Za-z]{1,3})?/, "\\.t"
    )
    File.write(formula, livecheckable.join("\n") + "\n")
    # Livecheck output after updation
    livecheck_post = JSON.parse(`brew livecheck --json #{formula_name}`)
    # If the output isn't the same, revert and notify
    if livecheck_pre != livecheck_post
      bar.log "\e[0;34m#{name}:\e[0m \e[0;31mmismatch after updation!\e[0m"
      File.write(formula, old_livecheckable.join("\n") + "\n")
    else
      bar.log "\e[0;34m#{name}:\e[0m \e[0;32mupdated!\e[0m"
    end
    bar.increment
  end
end

shortstat = `cd #{livecheckables_dir}; git diff --shortstat`
puts "\e[0;34mgit diff --shortstat\e[0m#{shortstat}"
