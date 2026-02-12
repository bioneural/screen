# screen

Classifier engine for the prophet system. A single shared implementation for LLM-based condition evaluation — one template, one test target.

## Structure

```
bin/classify                  standalone classifier (stdin JSON → stdout yes/no)
lib/classifier.rb             prompt template + model config + input builder
test/generative-classifiers   self-maintaining generative test harness
test/fixtures/classifiers.yml persisted test cases
```

## Usage

### As a subprocess (hooker)

```sh
echo '{"condition":"the file contains source code","file_path":"lib/foo.rb","content":"class Foo; end"}' | bin/classify
# → yes
```

### As a library (lay)

```ruby
require '/path/to/screen/lib/classifier'

fields = build_classifier_input({ 'file_path' => 'lib/foo.rb', 'content' => 'class Foo; end' })
prompt = CLASSIFIER_TEMPLATE % { condition: 'the file contains source code', fields: fields }
```

## Prompt format

All classifier prompts use XML-only structure:

```
Does the following condition apply to this input? Answer "yes" or "no" only.

<condition>the file contains source code</condition>

<input>
<file_path>lib/foo.rb</file_path>
<content>class Foo; end</content>
</input>
```

## Dependencies

- Ruby stdlib
- ollama (gemma3:1b default model)
- claude CLI (for generative test fixture generation only)
