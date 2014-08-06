# irssi from cpp templates
irssi-internal: irssi.tmpl irssi.internal
	cpp -include irssi.internal irssi.tmpl irssi-internal

irssi.internal: irssi.internal.gpg
	gpg --yes --output $@ --decrypt $<

irssi.internal.gpg: irssi.internal
	gpg -e --batch -r A3745D90 --output $@ $<
