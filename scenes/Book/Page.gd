extends Control

## The internal leaf number this page is currently rendering. 1 & 2 are the
## covers, 3 is the brown inside cover, 4+ are paper. The book reads this to decide
## how to draw each leaf (see Book.set_texture).
var number := 0


func set_number(value):
	number = value
	$Background/Text.text = ""
	# Paper pages are displayed starting at 1 (internal page 4 reads "1", 5 reads
	# "2", ...). Covers and the inside cover (1, 2, 3) and any <1 leaf show none.
	$Background/Number.text = ("- " + str(value - 3) + " -") if value >= 4 else ""
