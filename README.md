<h1 align="center">
  s c r e e n
  <br>
  <sub>shared classifier engine for condition evaluation</sub>
</h1>

A prompt is load-bearing. Change the format — colon-delimited fields to XML, "You are a classifier..." to "Does the following condition apply?" — and a 1B model flips from correct to wrong. screen eliminates the surface area. One template. One input builder. One test target. Every consumer inherits the same prompt that was tested, not a local copy that drifted.

Ruby stdlib only. ollama for inference. No gems.

---

## How it works

screen evaluates plain-language conditions against structured input via a local LLM. The condition and input fields are wrapped in XML tags — no colon-delimited boundaries, no prose preamble. The model answers yes or no.

```
Does the following condition apply to this input? Answer "yes" or "no" only.

<condition>the file contains source code</condition>

<input>
<file_path>lib/foo.rb</file_path>
<content>class Foo; end</content>
</input>
```

Two integration paths:

**As a library** — require `lib/classifier.rb` directly. Use `CLASSIFIER_TEMPLATE`, `CLASSIFIER_MODEL`, and `build_classifier_input` to construct prompts, then call ollama yourself.

**As a subprocess** — call `bin/classify` via stdin/stdout. Send JSON, receive "yes" or "no". No require path needed — stays stdlib-only.

```sh
echo '{"condition":"the file contains source code","file_path":"lib/foo.rb","content":"class Foo; end"}' | bin/classify
# → yes
```

## Structure

```
bin/classify                  stdin JSON → stdout yes/no
lib/classifier.rb             CLASSIFIER_TEMPLATE + CLASSIFIER_MODEL + build_classifier_input
test/generative-classifiers   discover classifiers, generate fixtures, run, report
test/fixtures/classifiers.yml persisted test cases (auto-generated)
```

## Generative tests

`test/generative-classifiers` accepts directories as arguments, globs `context/**/*.md` in each for `classifier:` frontmatter, generates test fixtures via `claude -p` (5 positive, 5 negative), runs them against the production model with majority-wins voting (3 trials per case), and reports pass/fail. Orphaned fixtures are pruned. Failing conditions are offered for auto-rewrite. With no arguments, runs existing fixtures only.

```sh
test/generative-classifiers /path/to/repo1 /path/to/repo2   # discover + run
test/generative-classifiers --generate /path/to/repo1        # force regenerate
test/generative-classifiers                                  # run existing fixtures only
```

## Requirements

- Ruby (stdlib only)
- ollama with `gemma3:1b` (or model specified in condition)
- claude CLI (for fixture generation and auto-rewrite only)

---

## License

MIT — Kerry Ivan Kurian
