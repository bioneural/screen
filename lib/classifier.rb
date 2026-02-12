# lib/classifier.rb — classifier prompt template and model configuration
#
# Shared between bin/classify and test/generative-classifiers.
# Change the template here to update both production and tests.
#
# Used by: prophet/bin/lay (require), hooker/bin/hooker (via bin/classify subprocess)

CLASSIFIER_TEMPLATE = "Does the following condition apply to this input? " \
                      "Answer \"yes\" or \"no\" only.\n\n" \
                      "<condition>%{condition}</condition>\n\n" \
                      "<input>\n%{fields}\n</input>"

CLASSIFIER_MODEL = 'gemma3:1b'

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
