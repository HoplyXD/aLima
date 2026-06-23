class_name BanterBot
## A lightweight OFFLINE "chatbot": picks a varied, topic-aware buyer reply to the
## player's free-text banter, so the marketplace feels conversational even when the
## live LLM backend isn't reachable. When online, the real LLM reply replaces this.
##
## It reads the player's message for a topic (greeting, price talk, the item's story,
## a compliment, a question, politeness) and answers from a rotating pool so the buyer
## doesn't repeat itself. No state, no network — pure presentation flavour.

const _GREETING := [
	"Hello there. So — what are we looking at today?",
	"Kumusta! Let's talk shop.",
	"Good day to you. Show me what you've got.",
	"Ah, a familiar face. What's the piece?",
	"Hello, hello. I haven't got all day, mind.",
]

const _PRICE := [
	"My price reflects what it's worth — not a peso more.",
	"You can ask, but my wallet has opinions of its own.",
	"Money talks, but it doesn't shout. Let's stay reasonable.",
	"I've haggled with sharper sellers than you, friend.",
	"That number won't move much, I'll be honest.",
	"Tempting me won't loosen my purse strings that easily.",
]

const _STORY := [
	"A piece with a past, eh? Now you have my interest.",
	"Tell me more — provenance is half of what I pay for.",
	"Mm. If that story holds up, it's worth a second look.",
	"History like that doesn't grow on trees. Go on.",
	"I do love a piece that's lived a little.",
]

const _COMPLIMENT := [
	"Flattery's free, but it won't change my appraisal.",
	"Charming. Still won't get you an extra peso, though.",
	"Ha! You're good. The item still has to earn it, mind.",
	"Smooth talker. Let's see if the piece backs it up.",
	"Kind of you to say. Now, the object — let's focus.",
]

const _QUESTION := [
	"That depends on what the piece can prove.",
	"Hard to say — convince me and we'll see.",
	"Maybe. Maybe not. Show me more.",
	"You're full of questions. I'm full of caution.",
	"Let's just say I'm listening.",
]

const _POLITE := [
	"Well-mannered, I'll give you that. Let's deal fairly.",
	"Courtesy noted. It does help your case a little.",
	"A pleasure to do business with someone civil.",
	"Manners cost nothing — and I appreciate them.",
]

const _DEFAULT := [
	"Mm-hm. Go on, I'm listening.",
	"Is that so? Tell me more.",
	"Interesting. And the piece itself?",
	"Right, right. So where does that leave our deal?",
	"I hear you. But let's keep our eyes on the item.",
	"Sure, sure. Now — about that price.",
	"Fair enough. What else have you got for me?",
]


## A varied, topic-aware buyer reply to the player's free-text `player_text`.
static func reply(player_text: String) -> String:
	var pool := _pool_for(player_text.to_lower())
	return pool[randi() % pool.size()]


static func _pool_for(lower: String) -> Array:
	if _has_any(lower, ["hi", "hey", "hello", "kumusta", "magandang", "good morning", "good day"]):
		return _GREETING
	if _has_any(
		lower,
		[
			"price",
			"peso",
			"pesos",
			"money",
			"cheap",
			"expensive",
			"lower",
			"discount",
			"pay",
			"cost"
		]
	):
		return _PRICE
	if _has_any(
		lower,
		[
			"history",
			"old",
			"antique",
			"story",
			"heritage",
			"family",
			"grandma",
			"lola",
			"year",
			"ago"
		]
	):
		return _STORY
	if _has_any(
		lower, ["beautiful", "nice", "lovely", "great", "amazing", "smart", "kind", "good eye"]
	):
		return _COMPLIMENT
	if _has_any(lower, ["please", "thank", "thanks", "sorry", "salamat"]):
		return _POLITE
	if (
		lower.ends_with("?")
		or _has_any(lower, ["how", "what", "why", "would you", "can you", "do you"])
	):
		return _QUESTION
	return _DEFAULT


static func _has_any(haystack: String, needles: Array) -> bool:
	for needle in needles:
		if haystack.contains(needle):
			return true
	return false
