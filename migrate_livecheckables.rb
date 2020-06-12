#!/usr/bin/env ruby
# frozen-string-literal: true

# Author: Nanda H Krishna <nanda.harishankar@gmail.com>
# Migrate Livecheckables from homebrew-livecheck to homebrew-core

require "ruby-progressbar"

# Absolute path to Livecheckables
livecheckables_dir = `echo $(brew --repo homebrew/livecheck)`.strip
livecheckables_dir += "/Livecheckables/"

# Absolute path to Formulae
core_formulae_dir = `echo $(brew --repo homebrew/core)`.strip
core_formulae_dir += "/Formula/"

# If command-line args are given, migrate only those Formulae
# Else migrate all Formulae
formulae = if ARGV.empty?
             Dir[livecheckables_dir + "*.rb"]
           else
             ARGV.map { |s| livecheckables_dir + s + ".rb" }
           end
formulae = formulae.sort

# Progress bar
bar = ProgressBar.create(
  title: "Migrating",
  total: formulae.length,
  format: "\e[0;34m%t\e[0m: [%B] \e[0;34m%c/%C\e[0m"
)

formulae.each do |formula|
  name = formula.split("/")[-1]
  core_formula_path = core_formulae_dir + name
  # If non-existent, notify
  if !File.exist?(formula)
    bar.log "\e[0;34m#{name}:\e[0m \e[0;31mdoes not exist!\e[0m"
  # Process existing Formulae
  else
    # Read Livecheckable, extract all lines except first and last
    livecheckable = "\n" + File.read(formula).split("\n")[1..-2].join("\n")
    # Insert block before bottle, or head if it exists and bottle :unneeded
    # Due to the comment before bottle, jython requires an extra pos decrement
    core_formula = File.read(core_formula_path).split("\n")
    pos = core_formula.find_index { |s| s.include? "bottle :unneeded" }
    pos = if pos.nil? || !core_formula.find_index { |s| s.include? "head do" }
            core_formula.find_index { |s| s.include? "bottle" }
          else
            core_formula.find_index { |s| s.include? "head do" }
          end
    offset = name == "jython.rb" ? 2 : 1
    core_formula.insert(
      pos - offset,
      livecheckable
    )
    # Formula luajit requires extra "\n" at the end of the file
    newline = name == "luajit.rb" ? "\n\n" : "\n"
    # Re-write the Formula
    File.write(core_formula_path, core_formula.join("\n") + newline)
    bar.log "\e[0;34m#{name}:\e[0m \e[0;32mmigrated!\e[0m"
  end
  bar.increment
end

shortstat = `cd #{core_formulae_dir}; git diff --shortstat`
puts "\e[0;34mgit diff --shortstat\e[0m#{shortstat}"
