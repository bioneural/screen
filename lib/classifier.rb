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

CLASSIFIER_MODEL = 'claude-haiku-4-5-20251001'

ANTHROPIC_API_KEY = ENV['ANTHROPIC_API_KEY']
ANTHROPIC_API_BASE = ENV.fetch('ANTHROPIC_API_BASE', 'https://api.anthropic.com')

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

# Classify via Anthropic Messages API — binary yes/no.
# Returns { answer: 'yes'/'no', score: 1.0/0.0 } on success, nil on failure.
def classify_with_anthropic(prompt, model)
  raise "ANTHROPIC_API_KEY is required" unless ANTHROPIC_API_KEY

  uri = URI("#{ANTHROPIC_API_BASE}/v1/messages")
  req = Net::HTTP::Post.new(uri)
  req['Content-Type'] = 'application/json'
  req['x-api-key'] = ANTHROPIC_API_KEY
  req['anthropic-version'] = '2023-06-01'

  req.body = JSON.generate({
    model: model,
    max_tokens: 1,
    temperature: 0,
    messages: [{ role: 'user', content: prompt }]
  })

  http = Net::HTTP.new(uri.hostname, uri.port)
  http.use_ssl = uri.scheme == 'https'
  http.read_timeout = 30
  response = http.request(req)

  return nil unless response.is_a?(Net::HTTPSuccess)

  data = JSON.parse(response.body)
  text = data.dig('content', 0, 'text').to_s.strip.downcase
  answer = text.start_with?('yes') ? 'yes' : 'no'
  score = answer == 'yes' ? 1.0 : 0.0

  { answer: answer, score: score }
rescue RuntimeError
  raise
rescue => e
  nil
end
