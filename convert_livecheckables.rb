#!/usr/bin/env ruby
# frozen-string-literal: true

# Author: Nanda H Krishna <nanda.harishankar@gmail.com>
# Convert Livecheckables in homebrew-livecheck to block format

require "ruby-progressbar"

# Absolute path to Livecheckables
livecheckables_dir = `echo $(brew --repo homebrew/livecheck)`.strip
livecheckables_dir += "/Livecheckables/"

# If command-line args are given, convert only those Livecheckables
# Else convert all Livecheckables
livecheckables = if ARGV.empty?
                   Dir[livecheckables_dir + "*.rb"]
                 else
                   ARGV.map { |s| livecheckables_dir + s + ".rb" }
                 end
livecheckables = livecheckables.sort

# Progress bar
bar = ProgressBar.create(
  title: "Converting",
  total: livecheckables.length,
  format: "\e[0;34m%t\e[0m: [%B] \e[0;34m%c/%C\e[0m"
)

livecheckables.each do |livecheckable|
  name = livecheckable.split("/")[-1]
  # If non-existent, notify
  if !File.exist?(livecheckable)
    bar.log "\e[0;34m#{name}:\e[0m \e[0;31mdoes not exist!\e[0m"
  # Process existing Livecheckables
  else
    # Read Livecheckable, extract all lines except first and last
    # Replace multiple whitespaces with single space
    # Strip whitespaces at ends, if any
    # Remove:
    #   - /^livecheck\ :/
    #   - /^:/
    #   - /\ =>/
    #   - /,$/
    # Special handling:
    #   - /^regex\ / --> "regex("
    # Prepend "    "
    # Concat ")" to the regex and "\n" to all lines
    # Join with "\n"
    # Prepend "\n  livecheck do\n" and concat "  end"
    content = File.read(livecheckable).split("\n")
    pos = content.find_index { |s| s.start_with? "  livecheck" }
    block = content[pos..-2].map do |s|
      s.gsub(/\s+/m, " ").strip.gsub(/(^livecheck\ :|^:|\ =>|,$)/, "") \
       .gsub(/^regex\ /, "regex(").prepend("    ")
    end
    block.each do |line|
      line.concat(")") if line.include? "    regex("
      line.concat("\n")
    end
    block = block.join
    block.prepend("#{content[0..pos - 1].join("\n")}\n  livecheck do\n") \
         .concat("  end\nend")
    File.write(livecheckable, block + "\n")
    bar.log "\e[0;34m#{name}:\e[0m \e[0;32mmigrated!\e[0m"
  end
  bar.increment
end

shortstat = `cd #{livecheckables_dir}; git diff --shortstat`
puts "\e[0;34mgit diff --shortstat\e[0m#{shortstat}"
