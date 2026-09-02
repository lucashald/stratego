class_name StrategoLLMClient
extends Node

# Outbound OpenAI-compatible chat client: the game asks the model a question at
# the moment it needs the answer, rather than an external agent polling to find
# out whether anything has happened.
#
# That direction is the whole point. The inbound path (StrategoMCPBridge) hands
# a seat to a controller that connects and drives it, which means the
# controller has to keep asking "is it my turn yet". Here the round loop owns
# the timing: it fires a request when a faction needs orders and carries on.
#
# Endpoint-agnostic on purpose. Anything speaking /v1/chat/completions works -
# the local CLI bridge (which spends a Claude/Codex subscription instead of API
# credits), OpenRouter, or an LM Studio instance - so switching models is a
# settings change, not a code change.

## Emitted for every finished request, success or failure, always exactly once.
## Carries request_id because several factions have requests in flight at the
## same time and the caller has to tell the answers apart.
signal request_completed(request_id: int, ok: bool, content: String, error: String)

## Anything OpenAI-compatible. No trailing slash; "/chat/completions" is added.
var endpoint := "http://127.0.0.1:8787/v1"
## Sent as "Authorization: Bearer <key>". Empty sends no header at all, which
## is what a keyless local model wants - an empty Bearer is not the same thing.
var api_key := ""
var model := "sonnet"
var max_tokens := 800
var temperature := 0.7
## A faction that has not answered by now plays as an ordinary bot instead. The
## round must not be able to stall behind a slow model, so this is a deadline
## rather than a suggestion.
var timeout_seconds := 30.0

## HTTPRequest drives exactly one request at a time, so N concurrent factions
## need N nodes. They are pooled rather than created per call: a WEGO match
## asks on every round, and the churn is pure waste when the same handful of
## nodes can be reused all match.
var _pool: Array[HTTPRequest] = []
var _in_flight: Dictionary = {}
var _next_request_id := 1


## Sends a chat completion. Returns the id to match against request_completed.
## `messages` is the OpenAI shape: [{"role": "user", "content": "..."}].
func ask(messages: Array, options: Dictionary = {}) -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	if messages.is_empty():
		# Reported through the signal rather than returned, so that a caller
		# handling failures in one place does not also need a second path for
		# the ones that fail before any request goes out.
		_fail_deferred(request_id, "No messages supplied.")
		return request_id
	var http := _take_from_pool()
	http.timeout = float(options.get("timeout_seconds", timeout_seconds))
	var body := build_request_body(
		messages,
		String(options.get("model", model)),
		int(options.get("max_tokens", max_tokens)),
		float(options.get("temperature", temperature)),
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var key := String(options.get("api_key", api_key))
	if not key.is_empty():
		headers.append("Authorization: Bearer " + key)
	var url := String(options.get("endpoint", endpoint)).rstrip("/") + "/chat/completions"
	_in_flight[http] = request_id
	var error := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		_in_flight.erase(http)
		_release_to_pool(http)
		_fail_deferred(request_id, "Request could not be sent (error %d)." % error)
	return request_id


## Builds the request body. Separated from the I/O above so it can be checked
## without a network or a live endpoint.
static func build_request_body(messages: Array, model_name: String, tokens: int, temp: float) -> Dictionary:
	var body := {
		"model": model_name,
		"messages": messages,
		"max_tokens": tokens,
		"temperature": temp,
		# The local bridge fakes streaming anyway (it buffers the whole answer
		# and re-emits it as a single chunk), and HTTPRequest hands back one
		# complete response rather than a stream, so asking for it would add a
		# parsing step that buys nothing.
		"stream": false,
	}
	return body


## Pulls the assistant text out of a decoded response. Falls back to
## reasoning_content because some models (GLM among them) put their answer
## there and leave content empty, which otherwise reads as an empty reply.
static func extract_content(response: Dictionary) -> String:
	var choices: Array = response.get("choices", [])
	if choices.is_empty():
		return ""
	var message: Dictionary = choices[0].get("message", {})
	var content := String(message.get("content", ""))
	if content.is_empty():
		content = String(message.get("reasoning_content", ""))
	return content


## Reads a JSON object out of model prose. Models routinely wrap JSON in ```
## fences or introduce it with a sentence even when told not to, and a strict
## parse of the whole reply throws all of it away over presentation. Returns an
## empty Dictionary when there is no object to find.
static func extract_json_object(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return {}
	# Scan for the outermost balanced {...}, ignoring braces inside strings so
	# that a brace in a chat message cannot truncate the object early.
	var start := trimmed.find("{")
	if start < 0:
		return {}
	var depth := 0
	var in_string := false
	var escaped := false
	for index in range(start, trimmed.length()):
		var character := trimmed[index]
		if escaped:
			escaped = false
			continue
		if character == "\\":
			escaped = true
			continue
		if character == "\"":
			in_string = not in_string
			continue
		if in_string:
			continue
		if character == "{":
			depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0:
				var candidate := trimmed.substr(start, index - start + 1)
				var parsed: Variant = JSON.parse_string(candidate)
				return parsed if parsed is Dictionary else {}
	return {}


func _take_from_pool() -> HTTPRequest:
	for http in _pool:
		if not _in_flight.has(http):
			return http
	var created := HTTPRequest.new()
	# Godot reports the body in one piece, which is what the parsing above
	# expects; partial chunks would have to be reassembled by hand.
	created.request_completed.connect(_on_http_completed.bind(created))
	add_child(created)
	_pool.append(created)
	return created


func _release_to_pool(http: HTTPRequest) -> void:
	# Nothing to do but drop the in-flight claim: the node stays parented and
	# connected, ready for the next round's question.
	_in_flight.erase(http)


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if not _in_flight.has(http):
		return
	var request_id: int = _in_flight[http]
	_release_to_pool(http)
	if result != HTTPRequest.RESULT_SUCCESS:
		# Covers the timeout case too, which is the one that matters in play:
		# the caller hears about it and falls back to the scoring bot.
		request_completed.emit(request_id, false, "", "Transport failed (result %d)." % result)
		return
	var text := body.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		request_completed.emit(request_id, false, "", "HTTP %d: %s" % [response_code, text.strip_edges().left(400)])
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		request_completed.emit(request_id, false, "", "Response was not JSON.")
		return
	var content := extract_content(parsed)
	if content.is_empty():
		request_completed.emit(request_id, false, "", "Response carried no assistant content.")
		return
	request_completed.emit(request_id, true, content, "")


## Failures found before the request goes out are still delivered through the
## signal, and still on a later frame, so that a caller connecting to the
## signal after calling ask() cannot miss them.
func _fail_deferred(request_id: int, message: String) -> void:
	request_completed.emit.call_deferred(request_id, false, "", message)
