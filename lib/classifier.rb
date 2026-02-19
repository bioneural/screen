# lib/classifier.rb — classifier prompt template and model configuration
# MIT License — Copyright (c) 2026 Kerry Ivan Kurian
#
# Shared between bin/classify and test/generative-classifiers.
# Change the template here to update both production and tests.
#
# Consumers require this file directly or call bin/classify as a subprocess.

require 'net/http'
require 'json'
require 'uri'

CLASSIFIER_TEMPLATE = "Does the following condition apply to this input? " \
                      "Answer \"yes\" or \"no\" only.\n\n" \
                      "<condition>%{condition}</condition>\n\n" \
                      "<input>\n%{fields}\n</input>"

CLASSIFIER_MODEL = 'gemma3:1b'

OLLAMA_HOST = ENV['OLLAMA_HOST'] || 'http://localhost:11434'

# Build XML-structured input from flat field hash.
# Every field gets its own XML tag — no colon-delimited boundaries.
#
# Accepts: { 'file_path' => '...', 'command' => '...', 'prompt' => '...', 'content' => '...' }
# Callers are responsible for extracting flat fields from nested event structures.
def build_classifier_input(fields)
  parts = []
  parts << "<file_path>#{fields['file_path']}</file_path>" if fields['file_path']
  parts << "<command>#{fields['command']}</command>" if fields['command']
  parts << "<prompt>#{fields['prompt']}</prompt>" if fields['prompt']

  content = fields['content']
  if content
    sample = content.length > 500 ? content[0, 500] + "\n..." : content
    parts << "<content>#{sample}</content>"
  end

  parts.join("\n")
end

# Classify via ollama /api/chat with logprobs for a continuous confidence score.
# Returns { answer: 'yes'/'no', score: 0.0-1.0 } on success, nil on failure.
def classify_with_logprobs(prompt, model)
  uri = URI("#{OLLAMA_HOST}/api/chat")
  req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

  req.body = JSON.generate({
    model: model,
    messages: [{ role: 'user', content: prompt }],
    stream: false,
    logprobs: true,
    top_logprobs: 10,
    options: { temperature: 0.0, num_predict: 1 }
  })

  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.read_timeout = 30
    http.request(req)
  end

  return nil unless response.is_a?(Net::HTTPSuccess)

  data = JSON.parse(response.body)
  top = data.dig('logprobs', 0, 'top_logprobs')
  return nil unless top

  yes_lp = nil
  no_lp = nil
  top.each do |t|
    token = t['token'].strip.downcase
    yes_lp = t['logprob'] if token == 'yes' && yes_lp.nil?
    no_lp = t['logprob'] if token == 'no' && no_lp.nil?
  end

  score = if yes_lp && no_lp
    yes_p = Math.exp(yes_lp)
    no_p = Math.exp(no_lp)
    yes_p / (yes_p + no_p)
  elsif yes_lp
    1.0
  else
    0.0
  end

  { answer: score > 0.5 ? 'yes' : 'no', score: score }
rescue Errno::ECONNREFUSED
  nil
rescue => e
  nil
end
