#!/usr/bin/env ruby
# frozen-string-literal: true

# Author: Nanda H Krishna <nanda.harishankar@gmail.com>
# Add template Livecheckables for Formulae, in separate git branches

require "git"
require "ruby-progressbar"

# Absolute path to Livecheckables
livecheck_dir = `echo $(brew --repo homebrew/livecheck)`.strip
livecheckables_dir = livecheck_dir + "/Livecheckables/"

# Configuring git
g = Git.open(livecheck_dir)
g.branch("master").checkout

# Command-line arguments
livecheckables = ARGV.map { |s| livecheckables_dir + s + ".rb" }.sort

# Progress bar
bar = ProgressBar.create(
  title: "Adding",
  total: livecheckables.length,
  format: "\e[0;34m%t\e[0m: [%B] \e[0;34m%c/%C\e[0m"
)

# Convert Formula name to Livecheckable class name
def convert_name(name)
  name = name.sub(/^[a-z\d]*/, &:capitalize)
  name.gsub(%r{(?:-|(/))([a-z\d]*)}, "\\1\\2.capitalize") \
      .gsub("/", "::")
end

livecheckables.each do |livecheckable|
  name = livecheckable.split("/")[-1]
  formula_name = name.gsub(/\.rb$/, "")
  class_name = convert_name(formula_name)
  # If Livecheckable already exists, notify
  if File.exist?(livecheckable)
    bar.log "\e[0;34m#{name}:\e[0m \e[0;31malready exists!\e[0m"
  # Else if branch already exists, notify
  elsif !g.branches["add-" + formula_name].nil?
    bar.log "\e[0;34m#{name}:\e[0m \e[0;33mbranch already exists!\e[0m"
  # Create non-existent Livecheckables
  else
    content = "class #{class_name}\n  livecheck do\n    url \"\"\n" \
              "    regex(/#{formula_name}-v?(\\d+(?:\\.\\d+)+)\\.t/i)\n" \
              "  end\nend\n"
    g.branch("add-#{formula_name}").checkout
    g.chdir { File.write(livecheckable, content) }
    g.add
    g.commit("#{formula_name}: add livecheckable")
    g.branch("master").checkout
    bar.log "\e[0;34m#{name}:\e[0m \e[0;32mcreated!\e[0m"
  end
  bar.increment
end
