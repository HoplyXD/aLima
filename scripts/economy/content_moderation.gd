class_name ContentModeration
## Lightweight, offline check for free-text banter input. Flags clearly offensive or
## not-safe-for-work messages so a buyer can react (get offended and ghost the player).
##
## Deliberately conservative and keyword-based so it works WITHOUT the backend; when
## online, the server-side LLM guardrail can refine this. It is not a full profanity
## filter — it catches blatant cases to keep the exhibit build family-friendly.

## Whole-word markers (matched at a word start, so "class" doesn't trip "ass").
const _BLOCKED: Array[String] = [
	# profanity
	"fuck",
	"shit",
	"cunt",
	"asshole",
	"bastard",
	"bitch",
	"dickhead",
	# slurs / demeaning
	"slut",
	"whore",
	"retard",
	"moron",
	# racist / ethnic slurs (blocklist — flagged so the buyer blocks the player). Chosen
	# to avoid matching innocent words (e.g. "paki"/"jap"/"spic" are excluded because
	# they'd flag "pakistan"/"japan"/"spice").
	"nigger",
	"nigga",
	"chink",
	"gook",
	"kike",
	"wetback",
	"beaner",
	"raghead",
	"towelhead",
	"coon",
	# sexual / NSFW
	"sex",
	"sexy",
	"porn",
	"nude",
	"naked",
	"boob",
	"penis",
	"vagina",
	"horny",
	"nsfw",
]


## Multi-word phrases for romantic/creepy advances (hitting on the buyer, asking them
## out). Matched as substrings — phrased to avoid false positives on item talk like
## "I love this piece".
const _BLOCKED_PHRASES: Array[String] = [
	"date me",
	"go on a date",
	"go out with me",
	"will you date",
	"be my girlfriend",
	"be my boyfriend",
	"marry me",
	"love you",
	"i love u",
	"kiss me",
	"you're hot",
	"you are hot",
	"you're sexy",
	"you're cute",
	"you are cute",
]


## True when `text` contains a blatantly offensive / NSFW term, or a romantic/creepy
## advance toward the buyer.
static func is_inappropriate(text: String) -> bool:
	var lower := text.to_lower()
	for phrase in _BLOCKED_PHRASES:
		if lower.contains(phrase):
			return true
	for word in _BLOCKED:
		if _contains_word(lower, word):
			return true
	return false


## True if `needle` appears in `haystack` starting at a word boundary (so suffixes
## like "fucking" still match, but substrings inside other words like "ass" in "pass"
## do not).
static func _contains_word(haystack: String, needle: String) -> bool:
	var idx := haystack.find(needle)
	while idx != -1:
		var before := haystack[idx - 1] if idx > 0 else " "
		if not _is_letter(before):
			return true
		idx = haystack.find(needle, idx + 1)
	return false


static func _is_letter(ch: String) -> bool:
	return ch.length() == 1 and ch >= "a" and ch <= "z"
